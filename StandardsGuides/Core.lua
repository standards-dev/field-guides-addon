-- Standards.gg Field Guides: core (namespace, saved variables, data packs, main window, slash command)
-- Source: Standards.gg Field Guides - https://standards.gg/field-guides/
local ADDON, ns = ...

local SGG = {}
_G.StandardsGuides = SGG
ns.SGG = SGG
ns.Data = {}

ns.CREDIT = "Source: Standards.gg Field Guides - https://standards.gg/field-guides/"

-- Theme: the site's layout in the WoW UI palette (Blizzard's standard font and frame colours)
ns.C = {
	bg = { 0.039, 0.039, 0.039 },       -- frame background
	panel = { 0.086, 0.086, 0.086 },    -- cards and boxes
	panel2 = { 0.118, 0.118, 0.118 },   -- raised panels, notices
	inset = { 0.02, 0.02, 0.02 },       -- inputs
	line = { 0.251, 0.251, 0.251 },     -- 1px frame edges
	metal = { 0.5, 0.5, 0.5 },          -- open / hovered edges
	text = { 0.902, 0.902, 0.902 },     -- VERY_LIGHT_GRAY_COLOR
	muted = { 0.749, 0.749, 0.749 },    -- LIGHTGRAY
	dim = { 0.5, 0.5, 0.5 },            -- GRAY_FONT_COLOR
	gold = { 1, 0.82, 0 },              -- NORMAL_FONT_COLOR #ffd100
	goldHi = { 1, 1, 0.6 },             -- LIGHTYELLOW_FONT_COLOR
	green = { 0.118, 1, 0 },            -- GREEN (uncommon) #1eff00
	blue = { 0.443, 0.835, 1 },         -- link blue #71d5ff
	warn = { 1, 0.5, 0.25 },            -- ORANGE_FONT_COLOR
	red = { 1, 0.125, 0.125 },          -- RED_FONT_COLOR
	white = { 1, 1, 1 },                -- HIGHLIGHT_FONT_COLOR
	btnTop = { 0.55, 0.04, 0.02 },      -- red UI panel button
	btnBot = { 0.31, 0.01, 0.01 },
	btnEdge = { 0.8, 0.62, 0.12 },
}

ns.QUALITY = {
	[0] = { "Poor", "9d9d9d" }, [1] = { "Common", "ffffff" }, [2] = { "Uncommon", "1eff00" },
	[3] = { "Rare", "0070dd" }, [4] = { "Epic", "a335ee" }, [5] = { "Legendary", "ff8000" },
}
ns.UNKNOWN_QUALITY = { "Rarity unverified", "808080" }

-- ------------------------------------------------------------------ fonts (the site's Cinzel and Inter, shipped with the addon)
local FONT_DIR = "Interface\\AddOns\\StandardsGuides\\Fonts\\"
ns.FONT = {
	body = FONT_DIR .. "Inter-Regular.ttf",
	bold = FONT_DIR .. "Inter-SemiBold.ttf",
	head = FONT_DIR .. "Cinzel-SemiBold.ttf",
	mark = FONT_DIR .. "Cinzel-Bold.ttf",
	code = "Fonts\\ARIALN.TTF",
}
local function MakeFont(name, path, size, color, flags)
	local f = CreateFont(name)
	f:SetFont(path, size, flags or "")
	f:SetTextColor(color[1], color[2], color[3])
	f:SetJustifyH("LEFT")
	f:SetSpacing(3)
	return f
end
local FB, FS, FH = ns.FONT.body, ns.FONT.bold, ns.FONT.head
ns.F = {
	body = MakeFont("SGG_FontBody", FB, 13, ns.C.text),
	small = MakeFont("SGG_FontSmall", FB, 12, ns.C.muted),
	lede = MakeFont("SGG_FontLede", FB, 15, ns.C.muted),
	h1 = MakeFont("SGG_FontH1", FH, 40, ns.C.gold),
	h2 = MakeFont("SGG_FontH2", FH, 26, ns.C.gold),
	h3 = MakeFont("SGG_FontH3", FH, 18, ns.C.white),
	h4 = MakeFont("SGG_FontH4", FS, 13, ns.C.white),
	kicker = MakeFont("SGG_FontKicker", FS, 10, ns.C.gold),
	code = MakeFont("SGG_FontCode", ns.FONT.code, 13, ns.C.goldHi),
	nav = MakeFont("SGG_FontNav", FB, 13, ns.C.muted),
	button = MakeFont("SGG_FontButton", FS, 12, ns.C.text),
	spec = MakeFont("SGG_FontSpec", FB, 13, ns.C.muted),
	card = MakeFont("SGG_FontCard", FH, 22, ns.C.white),
	mark = MakeFont("SGG_FontMark", ns.FONT.mark, 19, ns.C.text),
}
ns.F.small:SetSpacing(2)
ns.F.h1:SetSpacing(0); ns.F.h2:SetSpacing(0)

-- Letter-spaced caps like the site's eyebrows (hair spaces between letters).
function ns.Track(s)
	s = tostring(s or ""):upper()
	return (s:gsub("([\1-\127\194-\244][\128-\191]*)", "%1\226\128\138"):gsub("\226\128\138$", ""))
end

-- Two-colour gradient on a texture, for every client generation (falls back to a flat colour).
function ns.Gradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
	tex:SetColorTexture(1, 1, 1, 1)
	if CreateColor and pcall(tex.SetGradient, tex, orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then return end
	if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, orient, r1, g1, b1, a1, r2, g2, b2, a2) then return end
	tex:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
end

-- ------------------------------------------------------------------ helpers
function ns.Hex(c)
	return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function ns.Norm(s)
	s = tostring(s or ""):lower()
	s = s:gsub("\226\128\152", "'"):gsub("\226\128\153", "'")
	s = s:gsub("[%s]+", " "):gsub("^ ", ""):gsub(" $", "")
	return s
end

-- talent / spell name matching ignores punctuation and case
function ns.Key(s)
	return (tostring(s or ""):lower():gsub("\226\128\153", "'"):gsub("[^%w]", ""))
end

function ns.StripCodes(s)
	return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|"))
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Standards.gg Guides:|r " .. tostring(msg))
end

-- Fill a frame with a flat colour and an optional 1px border (no Backdrop templates needed).
function ns.Skin(frame, bg, border, alpha)
	if not frame.sggBg then
		frame.sggBg = frame:CreateTexture(nil, "BACKGROUND")
		frame.sggBg:SetAllPoints()
	end
	bg = bg or ns.C.panel
	frame.sggBg:SetColorTexture(bg[1], bg[2], bg[3], alpha or 1)
	if border then
		if not frame.sggBorder then
			local b = {}
			for i = 1, 4 do b[i] = frame:CreateTexture(nil, "BORDER") end
			b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(1)
			b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(1)
			b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(1)
			b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(1)
			frame.sggBorder = b
		end
		for i = 1, 4 do frame.sggBorder[i]:SetColorTexture(border[1], border[2], border[3], 1) end
	end
end

-- Flat button in the site's style; the active state is a red WoW panel button with gold text.
local function Paint(b, hover)
	local C = ns.C
	if b.active then
		ns.Gradient(b.sggBg, "VERTICAL", C.btnBot[1], C.btnBot[2], C.btnBot[3], 1, C.btnTop[1], C.btnTop[2], C.btnTop[3], 1)
		for i = 1, 4 do b.sggBorder[i]:SetColorTexture(C.btnEdge[1], C.btnEdge[2], C.btnEdge[3], 1) end
		b.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		return
	end
	local bg = b.flat and { 0, 0, 0 } or C.panel2
	b.sggBg:SetColorTexture(bg[1], bg[2], bg[3], b.flat and 0 or 1)
	local e = hover and C.gold or (b.flat and C.line or C.line)
	for i = 1, 4 do b.sggBorder[i]:SetColorTexture(e[1], e[2], e[3], 1) end
	local t = hover and C.goldHi or (b.textColor or C.text)
	b.text:SetTextColor(t[1], t[2], t[3])
end
ns.PaintButton = Paint

function ns.Button(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 100, height or 22)
	ns.Skin(b, ns.C.panel2, ns.C.line)
	local fs = b:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(ns.F.button)
	fs:SetPoint("CENTER")
	fs:SetJustifyH("CENTER")
	b.text = fs
	function b:SetLabel(t) fs:SetText(t) end
	b:SetLabel(text or "")
	b:SetScript("OnEnter", function(self)
		Paint(self, true)
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(self.tip, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		Paint(self, false)
		if self.tip then GameTooltip:Hide() end
	end)
	function b:SetActive(on)
		self.active = on
		Paint(self, false)
	end
	-- outline-only variant (the site's spec buttons)
	function b:SetFlat(on, color)
		self.flat = on
		self.textColor = color
		Paint(self, false)
	end
	Paint(b, false)
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

-- Single-line search box without templates.
function ns.EditBox(parent, width, placeholder)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width, 22)
	e:SetAutoFocus(false)
	e:SetFontObject(ns.F.body)
	e:SetTextInsets(6, 6, 0, 0)
	ns.Skin(e, ns.C.inset, ns.C.line)
	local ph = e:CreateFontString(nil, "OVERLAY")
	ph:SetFontObject(ns.F.small)
	ph:SetPoint("LEFT", 7, 0)
	ph:SetText(placeholder or "")
	e.placeholder = ph
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function() ph:Hide() end)
	e:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then ph:Show() end end)
	return e
end

-- ------------------------------------------------------------------ data packs
local function LoadAddOnCompat(name)
	if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name) end
	return LoadAddOn(name)
end

function SGG:RegisterClassData(cls)
	cls.specById = {}
	for i, s in ipairs(cls.specs) do
		s.index = i
		cls.specById[s.id] = s
	end
	ns.Data[cls.key] = cls
end

function ns.GetClassData(key)
	if ns.Data[key] then return ns.Data[key] end
	local info
	for _, c in ipairs(ns.Hub.classes) do if c.key == key then info = c end end
	if not info then return nil end
	local ok, reason = LoadAddOnCompat("StandardsGuides_" .. info.name)
	if not ns.Data[key] then
		ns.Print(("The %s data pack could not be loaded (%s). Enable \"Standards.gg Field Guides - %s data\" in the AddOns list.")
			:format(info.name, tostring(reason or "unknown"), info.name))
		return nil
	end
	return ns.Data[key]
end

-- ------------------------------------------------------------------ saved variables
local DEFAULTS = { notes = {}, trees = {}, minimap = { angle = 200, hide = false }, scale = 1, last = nil }

local function InitDB()
	StandardsGuidesDB = StandardsGuidesDB or {}
	for k, v in pairs(DEFAULTS) do
		if StandardsGuidesDB[k] == nil then StandardsGuidesDB[k] = type(v) == "table" and CopyTable(v) or v end
	end
	ns.db = StandardsGuidesDB
end

-- ------------------------------------------------------------------ main window
local W, H = 1040, 700
function ns.CreateMain()
	if ns.main then return ns.main end
	local f = CreateFrame("Frame", "StandardsGuidesFrame", UIParent)
	f:SetSize(W, H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetScale(ns.db.scale or 1)
	ns.Skin(f, ns.C.bg, ns.C.line, 0.97)
	tinsert(UISpecialFrames, "StandardsGuidesFrame")

	-- top bar (drag handle)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(64)
	ns.Skin(bar, ns.C.bg, nil, 1)
	local sep = bar:CreateTexture(nil, "BORDER")
	sep:SetColorTexture(ns.C.line[1], ns.C.line[2], ns.C.line[3])
	sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetHeight(1)
	-- the site's glowing rule under the header: transparent -> gold -> transparent
	local g1 = bar:CreateTexture(nil, "ARTWORK")
	g1:SetPoint("BOTTOMLEFT"); g1:SetPoint("BOTTOMRIGHT", bar, "BOTTOM"); g1:SetHeight(1)
	ns.Gradient(g1, "HORIZONTAL", ns.C.gold[1], ns.C.gold[2], ns.C.gold[3], 0, ns.C.gold[1], ns.C.gold[2], ns.C.gold[3], 0.55)
	local g2 = bar:CreateTexture(nil, "ARTWORK")
	g2:SetPoint("BOTTOMLEFT", bar, "BOTTOM"); g2:SetPoint("BOTTOMRIGHT"); g2:SetHeight(1)
	ns.Gradient(g2, "HORIZONTAL", ns.C.gold[1], ns.C.gold[2], ns.C.gold[3], 0.55, ns.C.gold[1], ns.C.gold[2], ns.C.gold[3], 0)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() f:StartMoving() end)
	bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	f.bar = bar

	local close = ns.Button(bar, "x", 24, 24, function() f:Hide() end)
	close:SetPoint("RIGHT", -10, 0)
	close.tip = "Close (Esc)"

	f.hub = ns.CreateHub(f)
	f.guide = ns.CreateGuide(f)
	-- time every page render for /sgg perf
	for _, page in ipairs({ f.hub, f.guide }) do
		local render = page.Render
		page.Render = function(self, ...)
			local t0 = debugprofilestop and debugprofilestop()
			render(self, ...)
			if t0 then
				ns.perf = ns.perf or { count = 0, total = 0, worst = 0 }
				local ms = debugprofilestop() - t0
				ns.perf.last, ns.perf.count, ns.perf.total = ms, ns.perf.count + 1, ns.perf.total + ms
				ns.perf.worst = math.max(ns.perf.worst, ms)
			end
		end
	end
	f:Hide()
	ns.main = f
	return f
end

function ns.ShowHub()
	local f = ns.CreateMain()
	f.guide:Hide()
	f.hub:Show()
	f:Show()
end

function ns.OpenGuide(classKey, specId, anchor)
	local cls = ns.GetClassData(classKey)
	if not cls then return end
	local spec = cls.specById[specId] or cls.specs[1]
	local f = ns.CreateMain()
	f.hub:Hide()
	f:Show()
	f.guide:ShowGuide(cls, spec, anchor)
	ns.db.last = { classKey, spec.id }
end

function ns.Toggle()
	local f = ns.CreateMain()
	if f:IsShown() then f:Hide() else
		if not f.hub:IsShown() and not f.guide:IsShown() then f.hub:Show() end
		f:Show()
	end
end

-- ------------------------------------------------------------------ minimap button
local function MinimapButton()
	local b = CreateFrame("Button", "StandardsGuidesMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local icon = b:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	local function place()
		local a = math.rad(ns.db.minimap.angle or 200)
		b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
	end
	b:RegisterForDrag("LeftButton")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			ns.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			b:ClearAllPoints()
			place()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			local _, token = UnitClass("player")
			ns.OpenGuide(token:lower())
		else
			ns.Toggle()
		end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Standards.gg Field Guides", ns.C.gold[1], ns.C.gold[2], ns.C.gold[3])
		GameTooltip:AddLine("Left-click: open the field guides", 1, 1, 1)
		GameTooltip:AddLine("Right-click: your class guide", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	place()
	if ns.db.minimap.hide then b:Hide() end
	ns.minimapButton = b
end

-- ------------------------------------------------------------------ events and slash command
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		InitDB()
	elseif event == "PLAYER_LOGIN" then
		MinimapButton()
		if ns.CacheTalentTrees then ns.CacheTalentTrees() end
		if ns.Prewarm and C_Timer then C_Timer.After(6, ns.Prewarm) end
	end
end)

SLASH_STANDARDSGUIDES1 = "/sgg"
SLASH_STANDARDSGUIDES2 = "/guides"
SlashCmdList.STANDARDSGUIDES = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = msg:match("^(%S+)%s*(.-)$")
	if cmd == "minimap" then
		ns.db.minimap.hide = not ns.db.minimap.hide
		if ns.minimapButton then ns.minimapButton:SetShown(not ns.db.minimap.hide) end
		ns.Print("Minimap button " .. (ns.db.minimap.hide and "hidden" or "shown") .. ".")
	elseif cmd == "scale" and tonumber(arg) then
		ns.db.scale = math.max(0.5, math.min(1.5, tonumber(arg)))
		if ns.main then ns.main:SetScale(ns.db.scale) end
		ns.Print("Window scale " .. ns.db.scale)
	elseif cmd == "me" or cmd == "class" then
		local _, token = UnitClass("player")
		ns.OpenGuide(token:lower())
	elseif cmd == "reset" then
		if ns.main then ns.main:ClearAllPoints(); ns.main:SetPoint("CENTER") end
	elseif cmd == "perf" then
		local p = ns.perf
		if p then
			ns.Print(("Page renders: last %.1f ms, average %.1f ms, worst %.1f ms over %d renders."):format(p.last, p.total / p.count, p.worst, p.count))
		else
			ns.Print("No page has been rendered yet. Open a guide first.")
		end
		local lay = ns.main and ns.main.guide and ns.main.guide:IsShown() and ns.main.guide.lay
		if lay then
			local shown = 0
			for _, o in ipairs(lay.used) do if o.sggVis then shown = shown + 1 end end
			ns.Print(("Current guide: %d widgets placed, %d shown near the view."):format(#lay.used, shown))
		end
		if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
			UpdateAddOnMemoryUsage()
			local kb = 0
			for _, c in ipairs(ns.Hub.classes) do kb = kb + (GetAddOnMemoryUsage("StandardsGuides_" .. c.name) or 0) end
			ns.Print(("Memory: core %.0f KB, loaded class packs %.0f KB."):format(GetAddOnMemoryUsage(ADDON) or 0, kb))
		end
	elseif cmd == "help" then
		ns.Print("/sgg - open or close the hub   /sgg me - your class guide   /sgg <class> [spec] - open a guide")
		ns.Print("/sgg scale 0.5-1.5   /sgg minimap - toggle the minimap button   /sgg reset - recentre the window")
		ns.Print("/sgg perf - render time, shown widgets and memory")
	elseif cmd and ns.Hub then
		for _, c in ipairs(ns.Hub.classes) do
			if c.key == cmd then
				local spec
				for _, s in ipairs(c.specs) do if arg ~= "" and s.id:find(arg, 1, true) == 1 then spec = s.id end end
				ns.OpenGuide(c.key, spec)
				return
			end
		end
		ns.Toggle()
	else
		ns.Toggle()
	end
end
