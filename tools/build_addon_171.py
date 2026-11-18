#!/usr/bin/env python3
"""Rebuilds the item tables of the nine StandardsGuides_<Class>/Data.lua files for 1.7.1.

Input: rebuild.json (cards per class, per-spec gear brackets, quest giver entries) produced from the
MetaForge Forever database, the Forever Dungeon Journal addon and earlier Wowhead data.
Only items=, spec gearBrackets=, gearBrackets= and new quests= entries are replaced or added; the string
table S, specs, dungeons and professions are kept as they are."""
import json, re, sys, collections
from lupa import LuaRuntime

ROOT = sys.argv[1]; REB = sys.argv[2]
R = json.load(open(REB))
NONGEAR = {'Armor kits','Bag','Bandages','Devices','Elixirs','Enchanting','Explosives','Flasks','Food & Drink','Idols','Item enhancements','Librams','Other','Permanent','Potions','Reagent Bag','Remedies','Scopes','Soul Bag','Totems','Weapon oils','Weapon stones'}
NAMES = json.load(open('/tmp/wh/reagent_names.json')) if len(sys.argv) > 3 else {}

def lua_str(s):
    return '"' + str(s).replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','') + '"'

def lua_val(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v) if isinstance(v, float) else str(v)
    if isinstance(v, str): return lua_str(v)
    if isinstance(v, list): return '{' + ','.join(lua_val(x) for x in v) + '}'
    if isinstance(v, dict): return '{' + ','.join('%s=%s' % (k if re.fullmatch(r'[A-Za-z_]\w*', k) else '[%s]' % lua_str(k), lua_val(x)) for k, x in v.items()) + '}'
    raise TypeError(v)

def match_brace(s, i):
    """s[i] == '{'; return index after the matching '}' (string aware)."""
    d = 0; n = len(s); j = i
    while j < n:
        c = s[j]
        if c == '"':
            j += 1
            while s[j] != '"':
                if s[j] == '\\': j += 1
                j += 1
        elif c == '{': d += 1
        elif c == '}':
            d -= 1
            if d == 0: return j + 1
        j += 1
    raise ValueError('unbalanced')

def old_tables(path):
    L = LuaRuntime(unpack_returned_tuples=True); cap = {}
    L.execute('StandardsGuides={}')
    L.globals().StandardsGuides['RegisterClassData'] = lambda self, t: cap.setdefault('t', t)
    L.execute(open(path, encoding='utf-8').read())
    return cap['t']

def tolist(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else None

def fix_mats(m):
    if not m: return m
    return re.sub(r'item (\d+)', lambda x: NAMES.get(x.group(1), 'item ' + x.group(1)), m)

def item_of(c):
    d = collections.OrderedDict()
    d['n'] = c['name']; d['id'] = c['id']; d['k'] = 'd' if c['kind'] == 'dungeon' else 'c'
    d['q'] = c.get('quality') or 1
    if c.get('slot'): d['s'] = c['slot']
    if c.get('profession'): d['p'] = c['profession']
    if c.get('required_level'): d['rl'] = c['required_level']
    if c.get('pickup_level'): d['pl'] = c['pickup_level']
    if c.get('item_level'): d['il'] = c['item_level']
    d['a'] = c.get('acquisition') or ''
    d['w'] = {k: v for k, v in c['why'].items()}
    d['tt'] = c.get('tooltip_lines') or []
    if c.get('skill'): d['sk'] = c['skill']
    if c.get('materials'): d['m'] = fix_mats(c['materials'])
    if c.get('evidence'): d['e'] = c['evidence']
    if c.get('limitation'): d['li'] = c['limitation']
    if c['kind'] == 'dungeon' and c.get('dungeon'): d['dg'] = c['dungeon']
    d['sp'] = c['specs']
    m = re.match(r'^Quest reward · (.+?)(?: \(| ·|;|$)', c.get('acquisition') or '')
    if m: d['qk'] = m.group(1).strip().lower()
    return d


_KEEP = ('Quest level is not the minimum', 'Check recipe source and required profession', 'The item has no level requirement of its own', 'Some materials may only drop from raids', 'drop chance for', 'Check faction', 'Bind-on-pickup', 'Check prerequisites')
def clean_lim(l):
    if not l: return ''
    out = []
    m = re.search(r'Required station: ([^.]*?)\.?$', l)
    if m and 'not specified' not in m.group(1): out.append('Requires ' + m.group(1).strip() + '.')
    l2 = re.sub(r'Required station: [^.]*\.?', '', l)
    if l2.startswith('Dungeon trash drop; no single mob'): return 'Dungeon trash drop; no single mob is listed.'
    for sent in [x.strip() for x in re.split(r'(?<=\.)\s+', l2) if x.strip()]:
        if any(k in sent for k in _KEEP): out.append(sent)
    return ' '.join(out)
def clean_item(d):
    d.pop('e', None); d.pop('icon_url', None)
    lim = clean_lim(d.get('li'))
    if lim: d['li'] = lim
    else: d.pop('li', None)
    if isinstance(d.get('a'), str):
        d['a'] = d['a'].replace(' listed chance', ' drop chance').replace('recipe source not listed', 'recipe source unknown')
    if isinstance(d.get('tt'), list):
        d['tt'] = [x.replace('Catalog snapshot: other Forever databases report', 'Another listing reports').replace('the catalog lists shield block on this bow', 'shield block is listed on this bow') if isinstance(x, str) else x for x in d['tt']]
    return d

stats = {}
for cls, info in R.items():
    path = '%s/StandardsGuides_%s/Data.lua' % (ROOT, cls.capitalize())
    src = open(path, encoding='utf-8').read()
    old = old_tables(path)
    keep = collections.OrderedDict()
    for k, v in old['items'].items():
        ks = str(k)
        if ks.startswith('st-') or (v['k'] == 'c' and v['s'] in NONGEAR):
            keep[ks] = {kk: (tolist(vv) if hasattr(vv, 'items') and kk in ('tt', 'sp') else (dict(vv.items()) if hasattr(vv, 'items') else vv)) for kk, vv in v.items()}
    items = collections.OrderedDict(keep)
    newkeys = {}
    for c in info['cards']:
        if c['kind'] not in ('dungeon', 'crafted'): continue
        items[c['key']] = item_of(c); newkeys[c['key']] = 1
    for _v in items.values(): clean_item(_v)
    # quests: add giver entries that are not present yet
    oldq = {str(k) for k in old['quests'].keys()}
    addq = [(k, v) for k, v in info['Q'].items() if k not in oldq]
    for k, v in items.items():
        qk = v.get('qk')
        if qk and qk not in oldq and qk not in info['Q']: v.pop('qk')
    # brackets
    def blist(keys): return [k for k in keys if k in items]
    spec_br = {}
    for code, b in info['brackets'].items():
        out = []
        if b.get('quest'):
            out.append(collections.OrderedDict(b='Quest rewards', no="Quest rewards that fit this spec's stat priority, sorted by quest level. The tooltip names the quest, its level, the quest giver and the faction. Quest level is not the minimum pickup level.", keys=blist(b['quest'])))
        for lv in b['levels']:
            out.append(collections.OrderedDict(b=lv['bracket'], no=lv['note'], keys=blist(lv['keys'])))
        spec_br[code] = out
    union = []
    names = []
    for out in spec_br.values():
        for i, b in enumerate(out):
            if b['b'] not in names:
                names.append(b['b']); union.append(collections.OrderedDict(b=b['b'], no=b['no'], keys=[]))
    for out in spec_br.values():
        for b in out:
            u = next(x for x in union if x['b'] == b['b'])
            for k in b['keys']:
                if k not in u['keys']: u['keys'].append(k)
    # keep the Sunken Temple class-quest rewards visible in the quest bracket
    stk = [k for k in keep if k.startswith('st-')]
    for u in union:
        if u['b'].startswith('Quest'): u['keys'] = stk + u['keys']
    for code, out in spec_br.items():
        for b in out:
            if b['b'].startswith('Quest'): b['keys'] = [k for k in stk if code in (items[k].get('sp') or [code])] + b['keys']
    # ---------- text surgery
    def replace_table(s, name, new):
        i = s.index('\n' + name + '=', 0) + 1 if ('\n' + name + '=') in s else s.index(name + '=')
        j = s.index('{', i); e = match_brace(s, j)
        return s[:j] + new + s[e:]
    it_txt = '{' + ','.join('[%s]=%s' % (lua_str(k), lua_val(v)) for k, v in items.items()) + '}'
    # items=
    i = src.index('items={['); j = src.index('{', i); e = match_brace(src, j)
    src = src[:j] + it_txt + src[e:]
    # quests= (append)
    i = src.index('quests={'); j = src.index('{', i); e = match_brace(src, j)
    add = ''.join(',[%s]=%s' % (lua_str(k), lua_val({kk: vv for kk, vv in v.items() if kk in ('q','npc','k','w','c','x','y','note')})) for k, v in addq)
    src = src[:e - 1] + add + src[e - 1:]
    # class-level gearBrackets=
    i = src.index('gearBrackets={'); j = src.index('{', i); e = match_brace(src, j)
    src = src[:j] + lua_val(union) + src[e:]
    # per-spec gearBrackets
    for code, out in spec_br.items():
        pat = 'token="%s",' % code
        assert src.count(pat) == 1, (cls, code, src.count(pat))
        src = src.replace(pat, pat + 'gearBrackets=%s,' % lua_val(out), 1)
    src = re.sub(r'Field Guides 1\.7\.0', 'Field Guides 1.7.1', src, count=1)
    open(path, 'w', encoding='utf-8', newline='\n').write(src)
    stats[cls] = (len(old['items']), len(items), len(newkeys), len(addq), sum(len(b['keys']) for b in union))
    print(cls, stats[cls])
