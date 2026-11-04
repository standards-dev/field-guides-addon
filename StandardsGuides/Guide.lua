-- Standards.gg Field Guides: guide page (header, spec tabs, search, section nav, content renderer).
local _, ns = ...
local C = ns.C

local NAV_W = 200
local PAD = 22

local function SpellIcon(name) return (ns.SpellIcon(name)) end -- icons come from the client (Icons.lua)

-- ------------------------------------------------------------------ macros
local function MacroName(name)
	name = name:gsub("^Mouseover ", "MO "):gsub(" — ", " "):gsub("[^\32-\126]", ""):gsub("%s+", " ")
	return name:sub(1, 16)
end

local function MacroSpell(code)
	local s = code:match("#showtooltip ([^\n]+)")
	if s and s:match("%S") then return s end
	return code:match("/cast[^\n]-([%a' :]+)%s*$")
end
ns.MacroSpell = MacroSpell

function ns.CreateMacroFromGuide(name, code)
	if InCombatLockdown() then return ns.Print("Macros cannot be created in combat.") end
	local mname = MacroName(name)
	local body = code:sub(1, 255)
	local idx = GetMacroIndexByName(mname)
	if idx and idx > 0 then
		EditMacro(idx, mname, nil, body)
		ns.Print(("Updated macro \"%s\". It is on your cursor: drop it on an action bar."):format(mname))
	else
		local global, perChar = GetNumMacros()
		local maxG = MAX_ACCOUNT_MACROS or 120
		local maxC = MAX_CHARACTER_MACROS or 18
		local per
		if global < maxG then per = nil elseif perChar < maxC then per = true
		else return ns.Print("Your macro slots are full. Delete a macro in /macro first.") end
		local ok, res = pcall(CreateMacro, mname, "INV_MISC_QUESTIONMARK", body, per)
		if not ok or not res then return ns.Print("The game refused to create the macro: " .. tostring(res)) end
		idx = res
		ns.Print(("Created macro \"%s\". It is on your cursor: drop it on an action bar, or find it in /macro."):format(mname))
	end
	if idx and PickupMacro then PickupMacro(idx) end
end

local copyFrame
function ns.ShowCopy(title, text)
	if not copyFrame then
		local f = CreateFrame("Frame", "StandardsGuidesCopyFrame", UIParent)
		f:SetSize(460, 200)
		f:SetPoint("CENTER", 0, 120)
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)
		ns.Skin(f, C.bg, C.gold, 0.98)
		tinsert(UISpecialFrames, "StandardsGuidesCopyFrame")
		f.title = f:CreateFontString(nil, "OVERLAY")
		f.title:SetFontObject(ns.F.h4)
		f.title:SetPoint("TOPLEFT", 12, -12)
		local hint = f:CreateFontString(nil, "OVERLAY")
		hint:SetFontObject(ns.F.small)
		hint:SetPoint("TOPRIGHT", -12, -14)
		hint:SetText("Ctrl+C to copy, Esc to close")
		local e = CreateFrame("EditBox", nil, f)
		e:SetMultiLine(true)
		e:SetFontObject(ns.F.code)
		e:SetPoint("TOPLEFT", 12, -36)
		e:SetPoint("BOTTOMRIGHT", -12, 12)
		e:SetAutoFocus(true)
		e:SetScript("OnEscapePressed", function() f:Hide() end)
		e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.text); self:HighlightText() end end)
		f.edit = e
		copyFrame = f
	end
	copyFrame.title:SetText(title)
	copyFrame.text = text
	copyFrame.edit:SetText(text)
	copyFrame:Show()
	copyFrame.edit:SetFocus()
	copyFrame.edit:HighlightText()
end

-- ------------------------------------------------------------------ tables
function ns.RenderTable(lay, x, y, w, head, rows, widths)
	local n = #head
	if not widths then widths = {} for i = 1, n do widths[i] = 1 / n end end
	local y0 = y
	local cols, cx = {}, x
	for i = 1, n do cols[i] = { cx, math.floor(w * widths[i]) }; cx = cx + cols[i][2] end
	local hh = 0
	for i = 1, n do
		local _, h = lay:Text(ns.F.kicker, (head[i] or ""):upper(), cols[i][1] + 8, y + 7, cols[i][2] - 16)
		hh = math.max(hh, h)
	end
	lay:Rect(x, y, w, hh + 14, C.panel2)
	y = y + hh + 14
	for r, row in ipairs(rows) do
		local rh = 0
		for i = 1, n do
			local _, h = lay:Text(ns.F.body, row.c[i] or "", cols[i][1] + 8, y + 6, cols[i][2] - 16, row.u and C.blue or nil)
			rh = math.max(rh, h)
		end
		lay:Rect(x, y, w, rh + 12, r % 2 == 0 and C.panel or C.panel)
		lay:Rect(x, y + rh + 11, w, 1, C.line, 1, true)
		y = y + rh + 12
	end
	return y - y0
end

local function RanksTable(lay, g, x, y, w)
	local rows = {}
	for _, r in ipairs(g.spec.ranks) do
		rows[#rows + 1] = { c = { r.tree, r.name, r.r .. "/" .. r.max }, u = r.u }
	end
	return ns.RenderTable(lay, x, y, w, { "Tree", "Talent", "Rank" }, rows, { 0.25, 0.55, 0.2 }) + 12
end

local function OrderTable(lay, g, x, y, w)
	local rows = {}
	for _, o in ipairs(g.spec.order) do
		local lv = o.l1 == o.l2 and tostring(o.l1) or (o.l1 .. "–" .. o.l2)
		local rk = (o.r1 == o.r2 and tostring(o.r2) or (o.r1 .. "–" .. o.r2)) .. "/" .. o.max
		rows[#rows + 1] = { c = { lv, o.tree, o.name, rk }, u = o.u }
	end
	return ns.RenderTable(lay, x, y, w, { "Level", "Tree", "Talent", "Resulting rank" }, rows, { 0.15, 0.22, 0.43, 0.2 }) + 12
end

-- ------------------------------------------------------------------ notes editor
local function NotesWidget(lay, g, x, y, w)
	if not g.notes then
		local box = CreateFrame("Frame", nil, g.scroll.content)
		ns.Skin(box, C.inset, C.line)
		local sf = CreateFrame("ScrollFrame", nil, box)
		sf:SetPoint("TOPLEFT", 8, -8)
		sf:SetPoint("BOTTOMRIGHT", -8, 8)
		local e = CreateFrame("EditBox", nil, sf)
		e:SetMultiLine(true)
		e:SetAutoFocus(false)
		e:SetFontObject(ns.F.body)
		e:SetMaxLetters(5000)
		sf:SetScrollChild(e)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, d)
			self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 30)))
		end)
		e:SetScript("OnCursorChanged", function(_, _, cy, _, ch)
			local top, bottom = sf:GetVerticalScroll(), sf:GetVerticalScroll() + sf:GetHeight()
			cy = -cy
			if cy < top then sf:SetVerticalScroll(cy) elseif cy + ch > bottom then sf:SetVerticalScroll(cy + ch - sf:GetHeight()) end
		end)
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		e:SetScript("OnTextChanged", function(self, user)
			if user and g.notesKey then ns.db.notes[g.notesKey] = self:GetText() end
		end)
		box:EnableMouse(true)
		box:SetScript("OnMouseDown", function() e:SetFocus() end)
		box.edit = e
		g.notes = box
	end
	local box = g.notes
	box:SetSize(w, 170)
	box.edit:SetWidth(w - 16)
	g.notesKey = g.cls.key .. "/" .. g.spec.id
	if box.edit:GetText() ~= (ns.db.notes[g.notesKey] or "") then box.edit:SetText(ns.db.notes[g.notesKey] or "") end
	lay:Place(box, x, y)
	local _, h = lay:Text(ns.F.small, "Your gearing priorities, quest progress or corrections. Saved for this specialization on this account.", x, y + 176, w)
	return 176 + h + 12
end

-- ------------------------------------------------------------------ block renderer
local WIDGETS = {
	talents = function(lay, g, x, y, w) return ns.RenderTalents(lay, g, x, y, w) end,
	ranks = RanksTable,
	order = OrderTable,
	loot = function(lay, g, x, y, w) return ns.RenderLoot(lay, g, x, y, w) end,
	craft = function(lay, g, x, y, w) return ns.RenderCraft(lay, g, x, y, w) end,
	quest = function(lay, g, x, y, w) return ns.RenderQuest(lay, g, x, y, w) end,
	prof = function(lay, g, x, y, w) return ns.RenderProfessions(lay, g, x, y, w) end,
	rarity = function(lay, g, x, y, w) return ns.RenderRarity(lay, g, x, y, w) end,
	notes = NotesWidget,
}

local function Pills(lay, x, y, w, list)
	local px, py, rowH = x, y, 0
	for _, p in ipairs(list) do
		local fs = lay:Text(ns.F.small, p, 0, 0, 400)
		local tw = math.min(w, fs:GetStringWidth() + 2)
		fs:SetWidth(tw)
		local bw = tw + 24
		if px + bw > x + w then px = x; py = py + rowH + 8; rowH = 0 end
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", lay.content, "TOPLEFT", px + 12, -(py + 7))
		local h = fs:GetStringHeight()
		lay:Move(fs, py + 7, h)
		lay:Rect(px, py, bw, h + 14, C.panel)
		-- keep search positions right
		local s = lay.search[#lay.search]
		if s and s.fs == fs then s.x, s.y, s.w = px + 12, py + 7, tw end
		px = px + bw + 8
		rowH = math.max(rowH, h + 14)
	end
	return py - y + rowH + 14
end

local function MacroCard(lay, g, b, x, y, w)
	local pad = 12
	local spell = MacroSpell(b.code)
	local iconTex = SpellIcon(spell)
	local tx, tw = x + pad + 44, w - pad * 2 - 44
	local yy = y + pad
	local _, h = lay:Text(ns.F.h4, b.n, tx, yy, tw - 210, b.u and C.blue or nil)
	yy = yy + h + 4
	if b.x and b.x ~= "" then
		_, h = lay:Text(ns.F.body, b.x, tx, yy, tw, b.u and C.blue or nil)
		yy = yy + h + 6
	end
	local cfs, ch = lay:Text(ns.F.code, b.code:gsub("|", "||"), tx + 8, yy + 6, tw - 16)
	lay:Rect(tx, yy, tw, ch + 12, C.inset, 1, true)
	yy = yy + ch + 12 + pad
	local boxH = yy - y
	lay:Box(x, y, w, boxH, nil, nil, b.u and C.blue or nil)
	lay:Icon(x + pad, y + pad, 36, iconTex)
	lay:Button(x + w - pad - 200, y + pad - 2, 112, 22, "Create macro", function() ns.CreateMacroFromGuide(b.n, b.code) end,
		"Adds this macro to your macro list (or updates it) and puts it on your cursor.")
	lay:Button(x + w - pad - 82, y + pad - 2, 82, 22, "Copy", function() ns.ShowCopy(b.n, b.code) end)
	return boxH
end

local function Abilities(lay, names, x, y, w)
	local size, cellW = 36, 92
	local per = math.max(1, math.floor(w / cellW))
	local rows = 0
	for i, n in ipairs(names) do
		local col, row = (i - 1) % per, math.floor((i - 1) / per)
		rows = row + 1
		local cx, cy = x + col * cellW, y + row * 66
		local ic = lay:Icon(cx + (cellW - size) / 2 - 4, cy, size, SpellIcon(n))
		ic:SetScript("OnEnter", function(self) ns.SpellTooltip(self, n) end)
		lay:Text(ns.F.small, n, cx - 4, cy + size + 4, cellW, C.text, "CENTER")
	end
	return rows * 66 + 8
end

local SECTION_GAP = 34

function ns.RenderBlock(lay, g, b, x, y, w)
	local t = b.t
	local col = b.u and C.blue or nil
	if t == "anchor" then
		if b.id ~= "overview" then y = y + SECTION_GAP; lay:Rect(x, y - SECTION_GAP / 2, w, 1, C.line, 0.6) end
		lay.anchors[b.id] = y - 10
		return y
	elseif t == "kicker" then
		local _, h = lay:Text(ns.F.kicker, b.x:upper(), x, y, w)
		return y + h + 6
	elseif t == "h1" then
		local _, h = lay:Text(ns.F.h1, b.x, x, y, w)
		y = y + h + 2
		if b.sub then
			local _, h2 = lay:Text(ns.F.h2, b.sub, x, y, w, C.gold)
			y = y + h2
		end
		return y + 14
	elseif t == "h2" then
		local _, h = lay:Text(ns.F.h2, b.x, x, y, w, col)
		return y + h + 12
	elseif t == "h3" then
		local _, h = lay:Text(ns.F.h3, b.x, x, y + 4, w, col)
		return y + h + 12
	elseif t == "h4" then
		if b.s == "summary" then
			local _, h = lay:Text(ns.F.h4, b.x, x, y + 6, w, col or C.gold)
			return y + h + 12
		end
		local _, h = lay:Text(ns.F.h4, b.x, x, y + 4, w, col)
		return y + h + 8
	elseif t == "p" then
		local s = b.s
		if s == "notice" then
			local fs, h = lay:Text(ns.F.body, b.x, x + 16, y + 12, w - 30, col)
			lay:Box(x, y, w, h + 24, C.panel2, nil, C.gold)
			return y + h + 24 + 12
		elseif s == "eyebrow" then
			local _, h = lay:Text(ns.F.kicker, b.x:upper(), x, y, w)
			return y + h + 8
		elseif s == "legend" then
			local _, h = lay:Text(ns.F.small, b.x, x, y, w, C.blue)
			return y + h + 10
		elseif s == "lede" then
			local _, h = lay:Text(ns.F.lede, b.x, x, y, math.min(w, 700), col)
			return y + h + 14
		elseif s == "small" or s == "bracket-note" or s == "aside-note" then
			local _, h = lay:Text(ns.F.small, b.x, x, y, w, col)
			return y + h + 8
		elseif s == "level" then
			local _, h = lay:Text(ns.F.h4, b.x, x + 14, y + 6, w - 14, col or C.gold)
			lay:Rect(x, y + 4, 3, h + 4, C.gold)
			return y + h + 12
		elseif s == "li" then
			local _, h = lay:Text(ns.F.body, "•  " .. b.x, x + 8, y, w - 8, col)
			return y + h + 6
		end
		local _, h = lay:Text(ns.F.body, b.x, x, y, w, col)
		return y + h + 10
	elseif t == "pills" then
		return y + Pills(lay, x, y, w, b.list)
	elseif t == "stat" then
		local text = "|cff" .. ns.Hex(C.gold) .. b.i .. ".|r  |cffffffff" .. b.b .. "|r" ..
			(b.x ~= "" and ("  |cff" .. ns.Hex(C.muted) .. b.x .. "|r") or "")
		local _, h = lay:Text(ns.F.body, text, x + 10, y + 6, w - 20, col)
		lay:Rect(x, y, w, h + 12, C.panel)
		return y + h + 14
	elseif t == "table" then
		return y + ns.RenderTable(lay, x, y, w, b.head, b.rows) + 12
	elseif t == "macro" then
		return y + MacroCard(lay, g, b, x, y, w) + 10
	elseif t == "abil" then
		return y + Abilities(lay, b.names, x, y + 6, w) + 6
	elseif t == "code" then
		local _, h = lay:Text(ns.F.code, b.x:gsub("|", "||"), x + 8, y + 6, w - 16)
		lay:Rect(x, y, w, h + 12, C.inset)
		return y + h + 20
	elseif t == "widget" then
		local fn = WIDGETS[b.w]
		if fn then return y + fn(lay, g, x, y, w) end
	end
	return y
end

-- ------------------------------------------------------------------ guide frame
function ns.CreateGuide(main)
	local g = CreateFrame("Frame", nil, main)
	g:SetPoint("TOPLEFT", 1, -65)
	g:SetPoint("BOTTOMRIGHT", -1, 1)
	g:Hide()

	-- header (lives in the main top bar, shown with the guide)
	local head = CreateFrame("Frame", nil, g)
	head:SetPoint("TOPLEFT", main.bar, "TOPLEFT")
	head:SetPoint("BOTTOMRIGHT", main.bar, "BOTTOMRIGHT", -44, 0)
	head:SetFrameLevel(main.bar:GetFrameLevel() + 2)
	local back = ns.Button(head, "ALL FIELD |cffffd100GUIDES|r", 140, 40, function() ns.ShowHub() end)
	back:SetPoint("LEFT", 22, 0)
	back.tip = "Back to all field guides"
	back.text:SetFontObject(ns.F.mark)
	back:SetFlat(true, C.text)
	back:SetWidth(math.ceil(back.text:GetStringWidth()) + 30)
	local brand = head:CreateFontString(nil, "OVERLAY")
	brand:SetFont(ns.FONT.head, 14, "")
	brand:SetTextColor(C.text[1], C.text[2], C.text[3])
	brand:SetPoint("LEFT", back, "RIGHT", 18, 0)
	g.brand = brand
	g.tabs = {}

	-- left column: search, section nav, aside note
	local side = CreateFrame("Frame", nil, g)
	side:SetPoint("TOPLEFT")
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(NAV_W)
	ns.Skin(side, C.bg)
	local sline = side:CreateTexture(nil, "BORDER")
	sline:SetColorTexture(C.line[1], C.line[2], C.line[3])
	sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT"); sline:SetWidth(1)

	local search = ns.EditBox(side, NAV_W - 24, "Search this guide...")
	search:SetPoint("TOPLEFT", 12, -12)
	g.search = search
	local prev = ns.Button(side, "^", 24, 20)
	prev:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -6)
	prev.tip = "Previous match"
	local nextB = ns.Button(side, "v", 24, 20)
	nextB:SetPoint("LEFT", prev, "RIGHT", 4, 0)
	nextB.tip = "Next match"
	local count = side:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(ns.F.small)
	count:SetPoint("LEFT", nextB, "RIGHT", 8, 0)
	g.searchCount = count

	g.nav = {}
	local navTop = CreateFrame("Frame", nil, side)
	navTop:SetPoint("TOPLEFT", 0, -72)
	navTop:SetSize(NAV_W, 10)
	g.navTop = navTop
	local note = side:CreateFontString(nil, "OVERLAY")
	note:SetFontObject(ns.F.small)
	note:SetWidth(NAV_W - 28)
	note:SetJustifyH("LEFT")
	g.asideNote = note

	-- content
	local sf = ns.ScrollArea(g)
	sf:SetPoint("TOPLEFT", NAV_W + 1, 0)
	sf:SetPoint("BOTTOMRIGHT", -14, 0)
	g.scroll = sf
	g.lay = ns.NewLayout(sf.content)
	g.hl = {}

	-- ---------------------------------------------------------------- search
	local matches, cur = {}, 0
	local function ClearHL()
		for _, t in ipairs(g.hl) do t:Hide() end
	end
	local function ShowMatch(i)
		if #matches == 0 then return end
		cur = ((i - 1) % #matches) + 1
		local m = matches[cur]
		for j, t in ipairs(g.hl) do
			if j <= #matches then
				t:SetColorTexture(1, 0.82, 0.2, j == cur and 0.35 or 0.15)
			end
		end
		sf:ScrollTo(m.y - 60)
		count:SetText(cur .. " / " .. #matches)
	end
	function g:RunSearch(keepIndex)
		ClearHL()
		wipe(matches)
		local q = search:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "")
		if #q < 2 then count:SetText(""); prev:Disable(); nextB:Disable(); return end
		for _, s in ipairs(g.lay.search) do
			local t = s.text
			if not t then t = ns.StripCodes(s.raw):lower(); s.text = t end
			if t:find(q, 1, true) then matches[#matches + 1] = s end
		end
		table.sort(matches, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
		for i, m in ipairs(matches) do
			local t = g.hl[i]
			if not t then t = sf.content:CreateTexture(nil, "BORDER", nil, 7); g.hl[i] = t end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", sf.content, "TOPLEFT", m.x - 3, -(m.y - 2))
			t:SetSize(m.w + 6, m.h + 4)
			t:SetColorTexture(1, 0.82, 0.2, 0.15)
			t:Show()
		end
		prev:SetEnabled(#matches > 0); nextB:SetEnabled(#matches > 0)
		if #matches == 0 then count:SetText("No matches") return end
		ShowMatch(keepIndex and cur > 0 and math.min(cur, #matches) or 1)
	end
	search:SetScript("OnTextChanged", function(_, user) if user then g:RunSearch() end end)
	search:SetScript("OnEnterPressed", function() ShowMatch(cur + 1) end)
	prev:SetScript("OnClick", function() ShowMatch(cur - 1) end)
	nextB:SetScript("OnClick", function() ShowMatch(cur + 1) end)
	prev:Disable(); nextB:Disable()

	-- ---------------------------------------------------------------- nav highlight while scrolling
	local function UpdateNav()
		local top = sf:GetVerticalScroll() + 40
		local active
		for _, b in ipairs(g.nav) do
			local y = b:IsShown() and b.anchorId and g.lay.anchors[b.anchorId]
			if y and y <= top then active = b end
		end
		for _, b in ipairs(g.nav) do
			local on = b == active
			b.fs:SetTextColor((on and C.gold or C.muted)[1], (on and C.gold or C.muted)[2], (on and C.gold or C.muted)[3])
			b.bar:SetShown(on)
		end
	end
	sf:HookScript("OnVerticalScroll", UpdateNav)

	-- ---------------------------------------------------------------- render
	function g:Render(keepScroll)
		local scroll = keepScroll and sf:GetVerticalScroll() or 0
		local lay = self.lay
		lay:Reset()
		lay:HidePlaced()
		local w = sf:GetWidth() - PAD * 2
		sf.content:SetWidth(sf:GetWidth())
		local y = 20
		for _, b in ipairs(self.spec.blocks) do
			y = ns.RenderBlock(lay, self, b, PAD, y, w)
		end
		local _, h = lay:Text(ns.F.small, ns.CREDIT, PAD, y + 20, w, C.gold)
		y = y + 20 + h + 30
		sf.content:SetHeight(y)
		sf:UpdateRange()
		sf:ScrollTo(scroll)
		self:RunSearch(true)
		UpdateNav()
	end

	function g:Rerender() self:Render(true) end

	local pending
	function g:RerenderSoon()
		if pending then return end
		pending = true
		C_Timer.After(0.25, function()
			pending = false
			if g:IsShown() then g:Render(true) end
		end)
	end

	function g:ShowGuide(cls, spec, anchor)
		ns.PrepareClass(cls)
		local changedClass = self.cls ~= cls
		self.cls, self.spec = cls, spec
		if changedClass then self.filters, self.open = {}, {} end
		if self.inputs then for _, e in pairs(self.inputs) do e:SetText(""); e.placeholder:Show() end end
		brand:SetText(("WOW FOREVER / %s FIELD GUIDES"):format(cls.name:upper()))
		-- spec tabs, right-aligned in the header
		for _, t in ipairs(self.tabs) do t:Hide() end
		local prevTab
		for i = #cls.specs, 1, -1 do
			local s = cls.specs[i]
			local t = self.tabs[i]
			if not t then t = ns.Button(head, "", 90, 32); t.text:SetFontObject(ns.F.spec); t:SetFlat(true, C.muted); self.tabs[i] = t end
			t:SetLabel(s.name)
			t:SetWidth(math.max(64, t.text:GetStringWidth() + 28))
			t:ClearAllPoints()
			if prevTab then t:SetPoint("RIGHT", prevTab, "LEFT", -6, 0) else t:SetPoint("RIGHT", head, "RIGHT", -6, 0) end
			t:SetActive(s == spec)
			t:SetScript("OnClick", function() ns.OpenGuide(cls.key, s.id) end)
			t:Show()
			prevTab = t
		end
		-- section nav
		for _, b in ipairs(self.nav) do b:Hide() end
		local prevNav
		for i, n in ipairs(spec.nav) do
			local b = self.nav[i]
			if not b then
				b = CreateFrame("Button", nil, side)
				b:SetSize(NAV_W - 1, 26)
				b.fs = b:CreateFontString(nil, "OVERLAY")
				b.fs:SetFontObject(ns.F.nav)
				b.fs:SetPoint("LEFT", 16, 0)
				b.fs:SetPoint("RIGHT", -6, 0)
				b.fs:SetJustifyH("LEFT")
				b.bar = b:CreateTexture(nil, "OVERLAY")
				b.bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3])
				b.bar:SetPoint("TOPLEFT", 4, -3); b.bar:SetPoint("BOTTOMLEFT", 4, 3); b.bar:SetWidth(2)
				local hl = b:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				hl:SetColorTexture(1, 1, 1, 0.05)
				b:SetScript("OnClick", function(self)
					local y = g.lay.anchors[self.anchorId]
					if y then sf:ScrollTo(y) end
				end)
				self.nav[i] = b
			end
			b.anchorId = n.id
			b.fs:SetText(n.x)
			b:ClearAllPoints()
			if prevNav then b:SetPoint("TOPLEFT", prevNav, "BOTTOMLEFT") else b:SetPoint("TOPLEFT", self.navTop, "TOPLEFT") end
			b:Show()
			prevNav = b
		end
		note:ClearAllPoints()
		note:SetPoint("TOPLEFT", prevNav or self.navTop, "BOTTOMLEFT", 14, -16)
		local asideText = (spec.asideNote or ""):gsub("Hover, focus or tap an item icon for its tooltip. Click to keep it open; Escape closes it.",
			"Hover an item icon for its tooltip. Shift-click links it in chat; Ctrl-click previews it.")
		note:SetText(asideText)
		self:Show()
		self:Render(false)
		if anchor and self.lay.anchors[anchor] then sf:ScrollTo(self.lay.anchors[anchor]) end
	end

	g:SetScript("OnShow", function(self) head:Show() end)
	return g
end
