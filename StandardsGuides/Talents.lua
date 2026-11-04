-- Standards.gg Field Guides: talent trees (drawn from the client's own talent data), level preview,
-- and "Apply build", which learns the guide's points in its leveling order, one point at a time.
local _, ns = ...
local C = ns.C

-- ------------------------------------------------------------------ client talent data
local function TabInfo(tab)
	local a, b, c, d, e, f = GetTalentTabInfo(tab)
	if type(a) == "number" and type(b) == "string" then return b, d, e, f end -- id, name, desc, icon, points, background
	return a, b, c, d -- name, icon, pointsSpent, background file
end

local function ReadTree()
	local n = GetNumTalentTabs and GetNumTalentTabs() or 0
	if n == 0 then return nil end
	local tree = { tabs = {} }
	for tab = 1, n do
		local name, _, _, bg = TabInfo(tab)
		local t = { name = name, bg = bg, talents = {} }
		for i = 1, (GetNumTalents(tab) or 0) do
			local tname, icon, tier, col, rank, max = GetTalentInfo(tab, i)
			if tname then
				local pre
				if GetTalentPrereqs then
					local pt, pc = GetTalentPrereqs(tab, i)
					if pt then pre = { pt, pc } end
				end
				t.talents[#t.talents + 1] = { n = tname, icon = icon, tier = tier, col = col, max = max, i = i, pre = pre, cur = rank }
			end
		end
		tree.tabs[tab] = t
	end
	return tree
end

function ns.CacheTalentTrees()
	local _, token = UnitClass("player")
	local tree = ReadTree()
	if tree and ns.db then
		local saved = { tabs = {} }
		for tab, t in ipairs(tree.tabs) do
			local s = { name = t.name, bg = t.bg, talents = {} }
			for _, x in ipairs(t.talents) do
				s.talents[#s.talents + 1] = { n = x.n, icon = x.icon, tier = x.tier, col = x.col, max = x.max, i = x.i, pre = x.pre }
			end
			saved.tabs[tab] = s
		end
		ns.db.trees[token] = saved
	end
	return tree
end

local function PlayerClassKey()
	local _, token = UnitClass("player")
	return token and token:lower()
end

-- ------------------------------------------------------------------ guide ranks
local function TreeIndex(tree, name)
	local k = ns.Key(name)
	for tab, t in ipairs(tree.tabs) do if ns.Key(t.name) == k then return tab end end
	for tab, t in ipairs(tree.tabs) do
		local tk = ns.Key(t.name)
		if tk:find(k, 1, true) == 1 or k:find(tk, 1, true) == 1 then return tab end
	end
end

local function FindTalent(tree, treeName, talentName)
	local k = ns.Key(talentName)
	local tab = TreeIndex(tree, treeName)
	if tab then
		for _, x in ipairs(tree.tabs[tab].talents) do if ns.Key(x.n) == k then return tab, x end end
	end
	for t, tt in ipairs(tree.tabs) do
		for _, x in ipairs(tt.talents) do if ns.Key(x.n) == k then return t, x end end
	end
end

-- Guide ranks at a given character level, keyed by talent name key.
local function RanksAt(spec, level)
	local m = {}
	if level >= 60 or #spec.order == 0 then
		for _, r in ipairs(spec.ranks) do m[ns.Key(r.name)] = r.r end
		return m
	end
	for _, o in ipairs(spec.order) do
		if level >= o.l1 then
			local r = o.r1 + (math.min(level, o.l2) - o.l1)
			local k = ns.Key(o.name)
			if (m[k] or 0) < r then m[k] = r end
		end
	end
	return m
end

-- ------------------------------------------------------------------ apply build
local function FreePoints()
	if GetUnspentTalentPoints then
		local ok, n = pcall(GetUnspentTalentPoints)
		if ok and n then return n end
	end
	if UnitCharacterPoints then return (UnitCharacterPoints("player")) or 0 end
	return 0
end

local function BuildSteps(spec, tree)
	local steps, missing = {}, {}
	local function add(treeName, name, rank)
		local tab, x = FindTalent(tree, treeName, name)
		if not tab then missing[name] = true; return end
		steps[#steps + 1] = { tab = tab, i = x.i, name = x.n, rank = rank, max = x.max }
	end
	if #spec.order > 0 then
		for _, o in ipairs(spec.order) do
			for r = o.r1, o.r2 do add(o.tree, o.name, r) end
		end
	else
		-- No leveling order in this guide: lowest tier first, so tier gates are always met.
		local list = {}
		for i, r in ipairs(spec.ranks) do
			local _, x = FindTalent(tree, r.tree, r.name)
			list[#list + 1] = { r = r, tier = x and x.tier or 99, i = i }
		end
		table.sort(list, function(a, b) if a.tier ~= b.tier then return a.tier < b.tier end return a.i < b.i end)
		for _, e in ipairs(list) do
			for r = 1, e.r.r do add(e.r.tree, e.r.name, r) end
		end
	end
	local miss = {}
	for k in pairs(missing) do miss[#miss + 1] = k end
	return steps, miss
end

local runner = { busy = false }
local function CurrentRank(tab, i)
	local _, _, _, _, rank = GetTalentInfo(tab, i)
	return rank or 0
end

local function Finish(msg)
	runner.busy = false
	ns.Print(msg)
	ns.CacheTalentTrees()
	if ns.main and ns.main.guide and ns.main.guide:IsShown() then ns.main.guide:Rerender() end
end

local function Step()
	local q = runner.queue
	while runner.qi <= #q and CurrentRank(q[runner.qi].tab, q[runner.qi].i) >= q[runner.qi].rank do
		runner.qi = runner.qi + 1
		runner.tries = 0
	end
	if runner.qi > #q then return Finish(("Done: your talents now follow the %s guide (%d points learned)."):format(runner.specName, runner.learned)) end
	if InCombatLockdown() then return Finish("Stopped: you entered combat. Run Apply build again afterwards.") end
	if FreePoints() <= 0 then
		return Finish(("Done: %d points learned. The rest of the %s build unlocks as you level."):format(runner.learned, runner.specName))
	end
	local s = q[runner.qi]
	runner.tries = (runner.tries or 0) + 1
	if runner.tries > 4 then
		return Finish(("Stopped at %s %d/%d: the game did not accept the point. Your spent points may differ from the guide (tier or prerequisite not met); reset talents at your class trainer to follow the build exactly.")
			:format(s.name, s.rank, s.max or 0))
	end
	if runner.tries == 1 then runner.learned = runner.learned + 1 end
	LearnTalent(s.tab, s.i)
	C_Timer.After(0.35, Step)
end

local function Deviations(spec, tree)
	local final = RanksAt(spec, 60)
	local n = 0
	for _, t in ipairs(tree.tabs) do
		for _, x in ipairs(t.talents) do
			if (x.cur or 0) > (final[ns.Key(x.n)] or 0) then n = n + 1 end
		end
	end
	return n
end

StaticPopupDialogs["STANDARDSGUIDES_APPLY"] = {
	text = "%s",
	button1 = "Apply",
	button2 = CANCEL or "Cancel",
	OnAccept = function(_, data) data() end,
	timeout = 0,
	whileDead = false,
	hideOnEscape = true,
	preferredIndex = 3,
}

function ns.ApplyBuild(cls, spec)
	if runner.busy then return ns.Print("Already applying a build.") end
	if PlayerClassKey() ~= cls.key then return ns.Print("Apply build only works on a " .. cls.name .. ".") end
	if InCombatLockdown() then return ns.Print("Talents cannot be learned in combat.") end
	if not LearnTalent then return ns.Print("This client does not let addons learn talents. Use the tree and point order as a checklist.") end
	local tree = ReadTree()
	if not tree then return ns.Print("Your talent trees are not available yet. Try again in a moment.") end
	local free = FreePoints()
	if free <= 0 then return ns.Print("You have no unspent talent points.") end
	local steps, missing = BuildSteps(spec, tree)
	if #missing > 0 then
		ns.Print("These guide talents were not found in your client's trees and will be skipped: " .. table.concat(missing, ", "))
	end
	if #steps == 0 then return end
	local text = ("Spend up to %d talent point%s following the %s %s guide%s?")
		:format(free, free == 1 and "" or "s", spec.name, cls.name, #spec.order > 0 and "'s leveling order" or "")
	local dev = Deviations(spec, tree)
	if dev > 0 then
		text = text .. ("\n\n|cffff8040Your current talents differ from the guide in %d talent%s. Points are added where the game allows; reset at your class trainer to follow the build exactly.|r")
			:format(dev, dev == 1 and "" or "s")
	end
	local dlg = StaticPopup_Show("STANDARDSGUIDES_APPLY", text)
	if dlg then
		dlg.data = function()
			runner.busy, runner.queue, runner.qi, runner.tries, runner.learned, runner.specName = true, steps, 1, 0, 0, spec.name
			Step()
		end
	end
end

-- ------------------------------------------------------------------ tree view
local function TalentEnter(self)
	local d = self.data
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local _, spellId = ns.SpellIcon(d.x.n)
	if d.live and GameTooltip.SetTalent then
		GameTooltip:SetTalent(d.tab, d.x.i)
	elseif spellId and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, spellId) then
		-- another class's talent: the client's spell tooltip for it
	else
		GameTooltip:AddLine(d.x.n, 1, 1, 1)
		GameTooltip:AddLine("Maximum rank " .. (d.x.max or "?"), C.muted[1], C.muted[2], C.muted[3])
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(("Guide at level %d: %d/%d"):format(d.level, d.gr, d.x.max or 0), C.gold[1], C.gold[2], C.gold[3])
	if d.live then GameTooltip:AddLine(("You: %d/%d"):format(d.x.cur or 0, d.x.max or 0), C.text[1], C.text[2], C.text[3]) end
	GameTooltip:Show()
end

local function Line(lay, x1, y1, x2, y2, color)
	if x1 == x2 then lay:Rect(x1 - 1, math.min(y1, y2), 2, math.abs(y2 - y1), color, 1, true)
	else lay:Rect(math.min(x1, x2), y1 - 1, math.abs(x2 - x1), 2, color, 1, true) end
end

function ns.RenderTalents(lay, g, x, y, w)
	local y0 = y
	local cls, spec = g.cls, g.spec
	local isMine = PlayerClassKey() == cls.key
	local tree = isMine and ReadTree() or (ns.db.trees[cls.token])
	g.previewLevel = g.previewLevel or 60
	local L = g.previewLevel

	-- toolbar
	lay:Button(x, y, 26, 22, "-", function()
		g.previewLevel = math.max(10, L - (IsShiftKeyDown() and 10 or 1)); g:Rerender()
	end, "Earlier level (Shift: 10 levels)")
	lay:Text(ns.F.h4, "Level " .. L, x + 32, y + 4, 70, nil, "CENTER")
	lay:Button(x + 106, y, 26, 22, "+", function()
		g.previewLevel = math.min(60, L + (IsShiftKeyDown() and 10 or 1)); g:Rerender()
	end, "Later level (Shift: 10 levels)")
	local ranks = RanksAt(spec, L)
	local total = 0
	for _, r in pairs(ranks) do total = total + r end
	lay:Text(ns.F.small, total .. " points" .. (#spec.order == 0 and L < 60 and " (this guide has no point order; showing level 60)" or ""), x + 140, y + 5, 300)
	if isMine then
		lay:Button(x + w - 130, y, 130, 22, "Apply build", function() ns.ApplyBuild(cls, spec) end,
			"Learn your unspent talent points following this guide's leveling order. Out of combat only; asks first.")
	end
	y = y + 32

	if not tree then
		local _, h = lay:Text(ns.F.body, ("The %s talent trees appear here after you log in a %s once (the game only shares a class's trees with that class). The selected ranks and point order are listed below.")
			:format(cls.name, cls.name), x, y, w, C.muted)
		return y - y0 + h + 12
	end

	local gap = 10
	local colW = math.floor((w - gap * 2) / 3)
	local cell = math.floor(colW / 4)
	local icon = math.min(34, cell - 14)
	local maxTier = 1
	for _, t in ipairs(tree.tabs) do for _, x2 in ipairs(t.talents) do maxTier = math.max(maxTier, x2.tier or 1) end end
	local rowH = icon + 16
	local treeH = 34 + maxTier * rowH + 8
	local missingNames = {}
	local found = {}
	for tab, t in ipairs(tree.tabs) do
		local tx = x + (tab - 1) * (colW + gap)
		lay:Box(tx, y, colW, treeH, C.inset)
		if t.bg and t.bg ~= "" then
			local bgTex = lay:Image(tx + 1, y + 1, colW - 2, treeH - 2, "Interface\\TalentFrame\\" .. t.bg .. "-TopLeft")
			bgTex:SetVertexColor(0.45, 0.45, 0.45, 1)
			bgTex:SetTexCoord(0, 1, 0, math.min(1, (treeH / colW) * 0.75))
		end
		local pts = 0
		for _, x2 in ipairs(t.talents) do pts = pts + (ranks[ns.Key(x2.n)] or 0) end
		lay:Text(ns.F.h3, t.name or ("Tree " .. tab), tx + 10, y + 8, colW - 70)
		lay:Text(ns.F.h4, "|cff" .. ns.Hex(C.gold) .. pts .. "|r", tx + colW - 50, y + 10, 40, nil, "RIGHT")
		local pos = {}
		for _, x2 in ipairs(t.talents) do
			local cx = tx + ((x2.col or 1) - 1) * cell + (cell - icon) / 2
			local cy = y + 34 + ((x2.tier or 1) - 1) * rowH + 4
			pos[(x2.tier or 1) .. ":" .. (x2.col or 1)] = { cx + icon / 2, cy + icon / 2 }
		end
		for _, x2 in ipairs(t.talents) do
			if x2.pre then
				local a = pos[x2.pre[1] .. ":" .. x2.pre[2]]
				local b = pos[(x2.tier or 1) .. ":" .. (x2.col or 1)]
				if a and b then
					local on = (ranks[ns.Key(x2.n)] or 0) > 0
					local col = on and C.gold or { 0.3, 0.3, 0.3 }
					if a[1] == b[1] or a[2] == b[2] then Line(lay, a[1], a[2], b[1], b[2], col)
					else Line(lay, a[1], a[2], b[1], a[2], col); Line(lay, b[1], a[2], b[1], b[2], col) end
				end
			end
		end
		for _, x2 in ipairs(t.talents) do
			local k = ns.Key(x2.n)
			found[k] = true
			local gr = ranks[k] or 0
			local p = pos[(x2.tier or 1) .. ":" .. (x2.col or 1)]
			local full = gr >= (x2.max or 1)
			local b = lay:Icon(p[1] - icon / 2, p[2] - icon / 2, icon, x2.icon or (ns.SpellIcon(x2.n)), gr == 0 and { 0.25, 0.25, 0.25 } or (full and C.gold or C.green))
			b.icon:SetDesaturated(gr == 0)
			if gr == 0 then b.icon:SetVertexColor(0.6, 0.6, 0.6) end
			if gr > 0 then
				b.count:SetText(gr .. "/" .. (x2.max or "?"))
				b.count:SetTextColor(full and C.gold[1] or C.green[1], full and C.gold[2] or C.green[2], full and C.gold[3] or C.green[3])
			elseif isMine and (x2.cur or 0) > 0 then
				b.count:SetText("|cffff2020" .. x2.cur .. "|r")
			end
			b.data = { x = x2, tab = tab, gr = gr, level = L, live = isMine }
			b:SetScript("OnEnter", TalentEnter)
		end
	end
	y = y + treeH + 8
	for _, r in ipairs(spec.ranks) do
		if not found[ns.Key(r.name)] then missingNames[#missingNames + 1] = r.name end
	end
	local legend = "|cff" .. ns.Hex(C.gold) .. "Gold|r: full rank   |cff" .. ns.Hex(C.green) .. "Green|r: partial rank   Grey: not taken"
	if isMine then legend = legend .. "   |cffff2020Red|r: points you have that the guide does not take" end
	local _, h = lay:Text(ns.F.small, legend, x, y, w)
	y = y + h + 6
	if #missingNames > 0 then
		_, h = lay:Text(ns.F.small, "|cffff8040Not found in " .. (isMine and "your client's" or "the cached") .. " trees: " .. table.concat(missingNames, ", ") .. ".|r", x, y, w)
		y = y + h + 6
	end
	if not isMine then
		_, h = lay:Text(ns.F.small, ("Trees from the last time you logged in a %s. Apply build is available on a %s."):format(cls.name, cls.name), x, y, w)
		y = y + h + 6
	end
	return y - y0 + 6
end

-- Keep the cached trees and any open guide current.
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
	if runner.busy then return end
	ns.CacheTalentTrees()
	local g = ns.main and ns.main.guide
	if g and g:IsShown() and g.cls and g.cls.key == PlayerClassKey() then g:RerenderSoon() end
end)
