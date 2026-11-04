-- Standards.gg Field Guides: item database views (loot atlas, professions, crafts, quest gear) and tooltips.
local _, ns = ...
local C = ns.C

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- ------------------------------------------------------------------ item helpers
function ns.Quality(q)
	return ns.QUALITY[q] or ns.UNKNOWN_QUALITY
end

-- Items the client has not loaded yet are requested; the open page and tooltip refresh when they arrive.
local RequestItem = C_Item and C_Item.RequestLoadItemDataByID
local pendingItems = {}
local function Request(id)
	if not id or pendingItems[id] then return end
	pendingItems[id] = true
	if RequestItem then pcall(RequestItem, id) else GetItemInfo(id) end
end

function ns.ItemIcon(it)
	local tex = it.id and GetItemIcon and GetItemIcon(it.id)
	if not tex and it.id then Request(it.id) end
	return tex or 134400 -- INV_Misc_QuestionMark until the client has it
end

local itemEvents = CreateFrame("Frame")
itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEvents:SetScript("OnEvent", function(_, _, id, ok)
	if pendingItems[id] ~= true then return end
	if ok == false then pendingItems[id] = "missing" return end
	pendingItems[id] = nil
	-- refresh an open tooltip for this item
	local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
	if owner and owner.data and owner.data.id == id and owner:IsMouseOver() then
		ns.ShowItemTooltip(owner, owner.data, owner.spec)
	end
	if ns.RefreshIcons then ns.RefreshIcons() end
end)

local function Compatible(it, spec)
	if not it.sp then return true end
	for _, s in ipairs(it.sp) do if s == spec.token then return true end end
	return false
end
ns.Compatible = Compatible

local function Why(it, spec)
	if type(it.w) == "table" then return it.w[spec.token] end
	return it.w or it.no
end

local EFFECT = { "equip:", "use:", "chance on hit:", "increases", "restores" }
local function isEffect(line)
	local l = line:lower()
	for _, p in ipairs(EFFECT) do if l:find(p, 1, true) then return true end end
	return false
end

-- Lower-case search blob per item, built on first use.
local blobs = setmetatable({}, { __mode = "k" })
local function Blob(it, spec)
	local b = blobs[it]
	if not b then
		local parts = { it.n, it.s, it.p, it.a, it.dg, it.m, it.sk, it.e, it.li, it.no, it.qk }
		if type(it.w) == "table" then for _, v in pairs(it.w) do parts[#parts + 1] = v end else parts[#parts + 1] = it.w end
		if it.tt then for _, v in ipairs(it.tt) do parts[#parts + 1] = v end end
		local t = {}
		for _, v in pairs(parts) do t[#t + 1] = tostring(v) end
		b = table.concat(t, " "):lower()
		blobs[it] = b
	end
	return b
end
local function Matches(it, q) return q == "" or Blob(it):find(q, 1, true) ~= nil end

local function EffLevel(it) return math.max(it.rl or 0, it.hl or 0) end
local function QuestLevel(it) return math.max(it.rl or 0, it.hl or 0, it.pl or 0) end

local function LinkFor(it)
	if not it.id then return nil end
	local _, link = GetItemInfo(it.id)
	if not link then Request(it.id) end
	return link
end

function ns.ShowItemTooltip(owner, it, spec)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local link = LinkFor(it)
	if link then
		GameTooltip:SetHyperlink(link)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Standards.gg guide notes", C.gold[1], C.gold[2], C.gold[3])
	else
		local q = ns.Quality(it.q)
		local r, g, b = tonumber(q[2]:sub(1, 2), 16) / 255, tonumber(q[2]:sub(3, 4), 16) / 255, tonumber(q[2]:sub(5, 6), 16) / 255
		GameTooltip:AddLine(it.n, r, g, b, true)
		local top = q[1] .. " · " .. (it.s or it.p or "Item")
		if it.il then top = top .. " · Item level " .. it.il end
		if it.id then top = top .. " · ID " .. it.id end
		GameTooltip:AddLine(top, C.muted[1], C.muted[2], C.muted[3], true)
		for _, line in ipairs(it.tt or { "Detailed stats not verified." }) do
			if isEffect(line) then GameTooltip:AddLine(line, 0.12, 1, 0, true) else GameTooltip:AddLine(line, 1, 1, 1, true) end
		end
		if it.rl then GameTooltip:AddLine("Requires level " .. it.rl, 1, 1, 1) end
	end
	if it.sk then GameTooltip:AddLine("Crafting / use skill: " .. it.sk, 1, 1, 1, true) end
	if it.m then GameTooltip:AddLine("Materials: " .. it.m, C.text[1], C.text[2], C.text[3], true) end
	if it.e then GameTooltip:AddLine(it.e, C.gold[1], C.gold[2], C.gold[3], true) end
	GameTooltip:AddLine(it.a or "Acquisition unresolved", C.text[1], C.text[2], C.text[3], true)
	if it.li then GameTooltip:AddLine(it.li, C.muted[1], C.muted[2], C.muted[3], true) end
	if not link and it.id then
		if pendingItems[it.id] == "missing" then
			GameTooltip:AddLine("Offline guide tooltip: this item is not in the game client.", 0.5, 0.5, 0.5, true)
		else
			GameTooltip:AddLine("Loading the game's tooltip for this item...", 0.5, 0.5, 0.5, true)
		end
	end
	GameTooltip:Show()
end

local function ItemClick(self, button)
	local it = self.data
	if not it then return end
	local link = LinkFor(it)
	if link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
		ChatEdit_InsertLink(link)
	elseif link and IsModifiedClick("DRESSUP") and DressUpItemLink then
		DressUpItemLink(link)
	end
end

local function ItemEnter(self) ns.ShowItemTooltip(self, self.data, self.spec) end

-- Small clickable item icon (used in audits and cards).
function ns.ItemIconButton(lay, x, y, size, it, spec)
	local q = ns.Quality(it.q)
	local col = { tonumber(q[2]:sub(1, 2), 16) / 255, tonumber(q[2]:sub(3, 4), 16) / 255, tonumber(q[2]:sub(5, 6), 16) / 255 }
	local b = lay:Icon(x, y, size, ns.ItemIcon(it), col)
	b.data, b.spec = it, spec
	b:SetScript("OnEnter", ItemEnter)
	b:SetScript("OnClick", ItemClick)
	return b
end

local WARN = { "unknown", "unverified", "preview", "untested", "unresolved" }
local function Badge(text)
	text = text or "Forever database"
	local l = text:lower()
	for _, w in ipairs(WARN) do
		if l:find(w, 1, true) then return "|cff" .. ns.Hex(C.warn) .. "[" .. text .. "]|r" end
	end
	return "|cff" .. ns.Hex(C.green) .. "[" .. text .. "]|r"
end
ns.Badge = Badge

-- One item card: icon + a single wrapped text block (name, meta, source, why, badge).
-- card text depends only on the item and spec, so it is built once per pair
local cardText = setmetatable({}, { __mode = "k" })
local MUTED_HEX = ns.Hex(C.muted)
local function CardText(it, spec)
	local bySpec = cardText[it]
	if not bySpec then bySpec = {}; cardText[it] = bySpec end
	local text = bySpec[spec]
	if text then return text end
	local q = ns.Quality(it.q)
	local meta = q[1] .. " · " .. (it.s or it.p or "Item") .. " · " ..
		(it.rl and ("Requires level " .. it.rl) or "Level requirement unresolved") ..
		(it.hl and (" · Hunter use: " .. it.hl .. "+") or "")
	local parts = {
		"|cff" .. q[2] .. it.n .. "|r",
		"|cff" .. MUTED_HEX .. meta .. "|r",
		"|cffffffff" .. (it.a or "Acquisition unresolved") .. "|r",
		Why(it, spec) or "Compare the tooltip with your current equipment.",
	}
	if it.k ~= "c" then parts[#parts + 1] = Badge(it.e) end
	text = table.concat(parts, "\n")
	bySpec[spec] = text
	return text
end

function ns.ItemCard(lay, x, y, w, it, spec, g)
	local text = CardText(it, spec)
	local pad = 8
	local textX, textW = x + pad + 40, w - pad * 2 - 40
	local hasQuest = it.qk and g.cls.quests[it.qk]
	if hasQuest then textW = textW - 130 end
	-- only the height is needed now; the card's widgets are built when it scrolls near the view
	local h = lay:Measure(ns.F.body, text, textW)
	local boxH = math.max(h, 34) + pad * 2
	lay:Index(text, textX, y + pad, textW, h)
	lay:Defer(y, boxH, function()
		local fs = lay:Text(ns.F.body, text, textX, y + pad, textW)
		lay:Box(x, y, w, boxH)
		fs:SetDrawLayer("OVERLAY")
		ns.ItemIconButton(lay, x + pad, y + pad, 34, it, spec)
		if hasQuest then
			lay:Button(x + w - pad - 124, y + pad, 124, 20, "Quest giver on Atlas", function()
				ns.ShowQuestAtlas(g.cls, it.qk)
			end, "Show the quest giver for " .. g.cls.quests[it.qk].q .. " on the map")
		end
	end)
	return boxH
end

-- ------------------------------------------------------------------ filter controls
local function SearchBox(g, key, placeholder, width)
	g.inputs = g.inputs or {}
	local e = g.inputs[key]
	if not e then
		e = ns.EditBox(g.scroll.content, width or 260, placeholder)
		e:SetScript("OnTextChanged", function(self, user)
			if user then g:RerenderSoon() end
		end)
		g.inputs[key] = e
	end
	return e
end

local function Query(g, key)
	local e = g.inputs and g.inputs[key]
	return e and e:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
end

local function Cycle(lay, g, key, x, y, w, label, options)
	g.filters = g.filters or {}
	local idx = g.filters[key] or 1
	local opt = options[idx]
	lay:Button(x, y, w, 22, label .. ": " .. opt[2], function()
		g.filters[key] = (idx % #options) + 1
		g:Rerender()
	end, "Click to change")
	return opt[1]
end

local LEVELS = { { 60, "Up to 60" }, { 19, "Up to 19" }, { 29, "Up to 29" }, { 39, "Up to 39" }, { 49, "Up to 49" } }

local function ResultCount(lay, x, y, w, text)
	local _, h = lay:Text(ns.F.small, text, x, y, w)
	return h + 10
end

-- ------------------------------------------------------------------ loot atlas
local function AuditItem(g, ref)
	return g.cls.byKey["audit-reference-" .. tostring(ref.id)] or g.cls.byId[ref.id]
end

local function RenderAudit(lay, g, d, x, y, w)
	local a = d.ra
	if not a then return 0 end
	local y0 = y
	local _, h = lay:Text(ns.F.h4, "Rare bosses, optional encounters & trash", x, y, w)
	y = y + h + 4
	_, h = lay:Text(ns.F.small, ("Reviewed %s. %s-relevant rare and trash candidates only. An available beta dungeon does not guarantee that every published drop assignment has been confirmed. Rarity describes item quality, not drop chance.")
		:format(a.ck or "?", g.cls.name), x, y, w)
	y = y + h + 6
	for _, r in ipairs(a.r or {}) do
		_, h = lay:Text(ns.F.body, "|cffffffff" .. r.n .. "|r  " .. Badge(r.st), x, y, w)
		y = y + h + 3
		if r.it and #r.it > 0 then
			local ix = x
			for _, ref in ipairs(r.it) do
				local it = AuditItem(g, ref)
				if it then
					ns.ItemIconButton(lay, ix, y, 22, it, g.spec)
					local fs, fh = lay:Text(ns.F.small, "|cff" .. ns.Quality(it.q)[2] .. it.n .. "|r", ix + 26, y + 4, 180)
					ix = ix + 30 + math.min(180, fs:GetStringWidth()) + 10
					if ix > x + w - 200 then ix = x; y = y + 26 end
				else
					local fs = lay:Text(ns.F.small, ref.n, ix, y + 4, 180)
					ix = ix + math.min(180, fs:GetStringWidth()) + 12
				end
			end
			y = y + 28
		else
			_, h = lay:Text(ns.F.small, ("No supported %s-relevant item in this audit."):format(g.cls.name), x, y, w)
			y = y + h + 3
		end
		if r.no and r.no ~= "" then
			_, h = lay:Text(ns.F.small, r.no, x, y, w)
			y = y + h + 6
		end
	end
	if a.t and #a.t > 0 then
		_, h = lay:Text(ns.F.h4, "Notable trash and shared-loot leads", x, y + 4, w)
		y = y + h + 8
		for _, t in ipairs(a.t) do
			local it = AuditItem(g, t)
			local tx = x
			if it then ns.ItemIconButton(lay, x, y, 20, it, g.spec); tx = x + 26 end
			local name = it and ("|cff" .. ns.Quality(it.q)[2] .. it.n .. "|r") or t.n
			_, h = lay:Text(ns.F.body, name .. " — " .. t.mob .. ". |cff" .. ns.Hex(C.muted) .. t.st .. ". " .. t.no .. "|r", tx, y + 2, w - (tx - x))
			y = y + math.max(h, 20) + 6
		end
	end
	for _, n in ipairs(a.no or {}) do
		_, h = lay:Text(ns.F.small, n, x, y, w)
		y = y + h + 4
	end
	return y - y0 + 6
end

function ns.RenderLoot(lay, g, x, y, w)
	local y0 = y
	local search = SearchBox(g, "loot", "Search dungeon, boss, item or stat...", 280)
	lay:Place(search, x, y)
	local bx = x + 290
	local max = Cycle(lay, g, "lootLevel", bx, y, 150, "Equip level", LEVELS)
	local status = Cycle(lay, g, "lootStatus", bx + 156, y, 200, "Coverage",
		{ { "all", "All known dungeons" }, { "items", "With item targets" }, { "unknown", "Unresolved loot" } })
	g.open = g.open or {}
	local q = Query(g, "loot")
	local dungeons = g.spec.dungeons or g.cls.dungeons or {}
	local anyClosed = false
	for _, d in ipairs(dungeons) do if not g.open[d.n] then anyClosed = true end end
	lay:Button(x + w - 100, y, 100, 22, anyClosed and "Expand all" or "Collapse all", function()
		for _, d in ipairs(dungeons) do g.open[d.n] = anyClosed end
		g:Rerender()
	end)
	y = y + 30
	local countY = y
	y = y + 20

	-- items per dungeon for this spec
	local byDungeon = {}
	for _, it in pairs(g.cls.items) do
		if it.k == "d" and it.dg and Compatible(it, g.spec) then
			local t = byDungeon[it.dg]
			if not t then t = {}; byDungeon[it.dg] = t end
			t[#t + 1] = it
		end
	end
	local shown, targets = 0, 0
	for _, d in ipairs(dungeons) do
		local all = byDungeon[d.n] or {}
		local dMatch = q == "" or (d.n .. " " .. (d.no or "") .. " " .. (d.lr or "")):lower():find(q, 1, true)
		local matched = {}
		for _, it in ipairs(all) do
			if EffLevel(it) <= max and (dMatch or Matches(it, q)) then matched[#matched + 1] = it end
		end
		local skip = (q ~= "" and not dMatch and #matched == 0) or (status == "items" and #matched == 0) or (status == "unknown" and #all > 0)
		if not skip then
			shown = shown + 1
			targets = targets + #matched
			table.sort(matched, function(a, b)
				if (a.rl or 99) ~= (b.rl or 99) then return (a.rl or 99) < (b.rl or 99) end
				return a.n < b.n
			end)
			local open = g.open[d.n] or q ~= ""
			-- header
			local badge = Badge(not d.ba and "Not yet confirmed" or (#all > 0 and "Beta dungeon · listed items" or "Beta dungeon · data incomplete"))
			local head = "|cff" .. ns.Hex(C.gold) .. (open and "-  " or "+  ") .. d.n .. "|r   " .. badge ..
				"   |cff" .. ns.Hex(C.muted) .. (d.lr or "Level range unresolved") .. " · " .. #all .. " relevant records|r"
			local fs, hh = lay:Text(ns.F.body, head, x + 10, y + 9, w - 110)
			local hH = math.max(30, hh + 16)
			lay:Box(x, y, w, hH, open and C.panel2 or ns.C.panel)
			local hit = lay:Hit(x, y, w - 90, hH, function()
				g.open[d.n] = not g.open[d.n]
				g:Rerender()
			end)
			if ns.AtlasPlace(d.n) then
				lay:Button(x + w - 80, y + (hH - 22) / 2, 72, 22, "Atlas", function() ns.ShowDungeonAtlas(d.n) end,
					"Show " .. d.n .. " on the map")
			end
			y = y + math.max(30, hh + 16) + 2
			if open then
				local ix, iw = x + 12, w - 12
				local _, h = lay:Text(ns.F.small, d.no or "Check current availability and entrance requirements.", ix, y + 6, iw)
				y = y + h + 12
				y = y + RenderAudit(lay, g, d, ix, y, iw)
				if #matched > 0 then
					for _, it in ipairs(matched) do
						y = y + ns.ItemCard(lay, ix, y, iw, it, g.spec, g) + 6
					end
				else
					local msg = not d.ba and "We do not have confirmed dungeon-drop data." or
						(#all > 0 and "No items match this filter. Clear the level/search filters to see other targets." or
						("No sufficiently supported %s loot data was found for this beta dungeon."):format(g.cls.name))
					_, h = lay:Text(ns.F.small, msg, ix, y, iw, C.warn)
					y = y + h + 8
				end
				y = y + 6
			end
		end
	end
	if shown == 0 then
		local _, h = lay:Text(ns.F.small, "No dungeons match. Try a broader search.", x, y, w)
		y = y + h + 6
	end
	lay:Text(ns.F.small, shown .. " dungeon entries · " .. targets .. " matching item records", x, countY, w)
	return y - y0 + 10
end

-- ------------------------------------------------------------------ crafting
local BRACKETS = { "1-19", "20-29", "30-39", "40-49", "50-60", "unknown" }
local function Bracket(it)
	local n = it.rl
	if not n then return "unknown" end
	return n < 20 and "1-19" or n < 30 and "20-29" or n < 40 and "30-39" or n < 50 and "40-49" or "50-60"
end

function ns.RenderCraft(lay, g, x, y, w)
	local y0 = y
	local search = SearchBox(g, "craft", "Search craft, profession, benefit or material...", 280)
	lay:Place(search, x, y)
	local bopts = { { "all", "All brackets" } }
	for _, b in ipairs(BRACKETS) do bopts[#bopts + 1] = { b, b == "unknown" and "Requirement unresolved" or b } end
	local br = Cycle(lay, g, "craftBracket", x + 290, y, 190, "Level", bopts)
	local profs, seen = { { "all", "All professions" } }, {}
	local plist = {}
	for _, it in pairs(g.cls.items) do
		if it.k == "c" and it.p and not seen[it.p] and Compatible(it, g.spec) then seen[it.p] = true; plist[#plist + 1] = it.p end
	end
	table.sort(plist)
	for _, p in ipairs(plist) do profs[#profs + 1] = { p, p } end
	local prof = Cycle(lay, g, "craftProf", x + 486, y, 220, "Profession", profs)
	y = y + 30
	local q = Query(g, "craft")
	local groups, n = {}, 0
	for _, it in pairs(g.cls.items) do
		if it.k == "c" and Compatible(it, g.spec) and Matches(it, q) and (br == "all" or Bracket(it) == br) and (prof == "all" or it.p == prof) then
			local b = Bracket(it)
			groups[b] = groups[b] or {}
			table.insert(groups[b], it)
			n = n + 1
		end
	end
	y = y + ResultCount(lay, x, y, w, n .. " matching crafts and consumables")
	for _, b in ipairs(BRACKETS) do
		local list = groups[b]
		if list then
			table.sort(list, function(a, c)
				if (a.rl or 99) ~= (c.rl or 99) then return (a.rl or 99) < (c.rl or 99) end
				return a.n < c.n
			end)
			local _, h = lay:Text(ns.F.h3, b == "unknown" and "Requirement unresolved" or ("Levels " .. b), x, y, w)
			y = y + h + 8
			for _, it in ipairs(list) do y = y + ns.ItemCard(lay, x, y, w, it, g.spec, g) + 6 end
			y = y + 8
		end
	end
	if n == 0 then
		local _, h = lay:Text(ns.F.small, "No crafts match. Try a broader search.", x, y, w)
		y = y + h + 6
	end
	return y - y0 + 6
end

-- ------------------------------------------------------------------ quest rewards and other gear
function ns.RenderQuest(lay, g, x, y, w)
	local y0 = y
	local search = SearchBox(g, "quest", "Search item, quest, slot or stat...", 280)
	lay:Place(search, x, y)
	local max = Cycle(lay, g, "questLevel", x + 290, y, 150, "Equip level", LEVELS)
	y = y + 30
	local q = Query(g, "quest")
	local countY = y
	y = y + 20
	local n = 0
	for _, b in ipairs(g.spec.gearBrackets or g.cls.gearBrackets or {}) do
		local list = {}
		local bMatch = q ~= "" and (b.b .. " " .. b.no):lower():find(q, 1, true)
		for _, key in ipairs(b.keys) do
			local it = g.cls.items[key]
			if it and Compatible(it, g.spec) and QuestLevel(it) <= max and (q == "" or Matches(it, q) or bMatch) then
				list[#list + 1] = it
			end
		end
		if #list > 0 then
			n = n + #list
			local _, h = lay:Text(ns.F.h3, (b.b:match("^%d") and "Levels " or "") .. b.b, x, y, w)
			y = y + h + 6
			_, h = lay:Text(ns.F.small, b.no, x, y, w)
			y = y + h + 8
			for _, it in ipairs(list) do y = y + ns.ItemCard(lay, x, y, w, it, g.spec, g) + 6 end
			y = y + 8
		end
	end
	if n == 0 then
		local _, h = lay:Text(ns.F.small, "No quest rewards or gear match. Try a broader search or a higher level.", x, y, w)
		y = y + h + 6
	end
	lay:Text(ns.F.small, n .. " matching quest rewards and gear sources", x, countY, w)
	return y - y0 + 6
end

-- ------------------------------------------------------------------ professions
function ns.RenderProfessions(lay, g, x, y, w)
	local y0 = y
	local list = g.spec.professions or g.cls.professions or {}
	local colW = math.floor((w - 12) / 2)
	local rowH = 0
	for i, p in ipairs(list) do
		local col = (i - 1) % 2
		local cx = x + col * (colW + 12)
		local text = "|cffffffff" .. p.n .. "|r\n" .. p.b
		if p.camp then text = text .. "\n|cffffffffCampsite:|r " .. p.camp end
		if p.cv then text = text .. "\n|cff" .. ns.Hex(C.muted) .. p.cv .. "|r" end
		local fs, h = lay:Text(ns.F.body, text, cx + 10, y + 10, colW - 20)
		lay:Box(cx, y, colW, h + 20)
		fs:SetDrawLayer("OVERLAY")
		rowH = math.max(rowH, h + 20)
		if col == 1 or i == #list then
			y = y + rowH + 10
			rowH = 0
		end
	end
	return y - y0
end

function ns.RenderRarity(lay, g, x, y, w)
	local t = "|cffffffffCommon|r    |cff1eff00Uncommon|r    |cff0070ddRare|r    |cffa335eeEpic|r    |cff808080Unverified rarity|r"
	local _, h = lay:Text(ns.F.body, t, x, y, w)
	return h + 10
end

-- Builds per-class lookups once.
function ns.PrepareClass(cls)
	if cls.byId then return end
	cls.byId, cls.byKey = {}, cls.items
	for _, it in pairs(cls.items) do
		if it.id and not cls.byId[it.id] then cls.byId[it.id] = it end
	end
end
