-- Standards.gg Field Guides: in-addon Atlas.
-- The website shows atlas.standards.gg in a popup. In game we draw the zone map from the
-- client's own map tiles, pin the dungeon entrance / quest giver, and can also pin it on the world map.
local _, ns = ...
local C = ns.C

-- World coordinates in the guides use the game's world X/Y, per continent.
local CONT = {
	["kalimdor"] = { inst = 1, map = 1414 },
	["eastern-kingdoms"] = { inst = 0, map = 1415 },
}

function ns.AtlasPlace(name)
	return ns.AtlasPlaces and ns.AtlasPlaces[ns.Norm(name)]
end

local function MapPos(inst, vec, mapID)
	local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, inst, vec, mapID)
	if ok and pos and pos.x and pos.x >= 0 and pos.x <= 1 and pos.y >= 0 and pos.y <= 1 then return pos.x, pos.y end
end

-- Returns zoneMapID, zx, zy, continentMapID, cx, cy (any may be nil when the client lacks the data).
local function Resolve(c, wx, wy)
	local ci = CONT[c]
	if not ci or not wx or not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
	local vec = CreateVector2D(wx, wy)
	local cx, cy = MapPos(ci.inst, vec, ci.map)
	if not cx then return end
	local info = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(ci.map, cx, cy)
	if info and info.mapID and info.mapID ~= ci.map then
		local zx, zy = MapPos(ci.inst, vec, info.mapID)
		if zx then return info.mapID, zx, zy, ci.map, cx, cy end
	end
	return ci.map, cx, cy, ci.map, cx, cy
end

-- ------------------------------------------------------------------ world map pin
local worldPin, worldTarget
local function UpdateWorldPin()
	if not worldPin or not worldTarget or not WorldMapFrame then return end
	local child = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
	local current = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
	local x, y
	if current == worldTarget.zone then x, y = worldTarget.zx, worldTarget.zy
	elseif current == worldTarget.cont then x, y = worldTarget.cx, worldTarget.cy end
	if not child or not x then worldPin:Hide(); return end
	worldPin:SetParent(child)
	worldPin:SetFrameLevel(child:GetFrameLevel() + 50)
	worldPin:ClearAllPoints()
	worldPin:SetPoint("CENTER", child, "TOPLEFT", x * child:GetWidth(), -y * child:GetHeight())
	worldPin:Show()
end

local function MakePin(parent, size)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(size, size)
	local ring = p:CreateTexture(nil, "ARTWORK")
	ring:SetAllPoints()
	ring:SetTexture("Interface\\COMMON\\Indicator-Yellow")
	local glow = p:CreateTexture(nil, "BACKGROUND")
	glow:SetPoint("CENTER")
	glow:SetSize(size * 2, size * 2)
	glow:SetTexture("Interface\\Cooldown\\star4")
	glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
	glow:SetBlendMode("ADD")
	local ag = glow:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1); a:SetToAlpha(0.2); a:SetDuration(0.8)
	ag:SetLooping("BOUNCE")
	ag:Play()
	return p
end

local hooked
function ns.PinOnWorldMap(t)
	if InCombatLockdown() then ns.Print("The world map cannot be opened by an addon in combat. " .. (t.coords or "")); return end
	worldTarget = t
	if not worldPin then worldPin = MakePin(UIParent, 22) end
	if C_Map.SetUserWaypoint and UiMapPoint and t.zone and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(t.zone)) then
		pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(t.zone, t.zx, t.zy))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
	end
	if OpenWorldMap then
		pcall(OpenWorldMap, t.zone)
	elseif WorldMapFrame then
		ShowUIPanel(WorldMapFrame)
	end
	if WorldMapFrame and WorldMapFrame.SetMapID and WorldMapFrame:GetMapID() ~= t.zone then pcall(WorldMapFrame.SetMapID, WorldMapFrame, t.zone) end
	if not hooked and WorldMapFrame then
		hooked = true
		if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdateWorldPin) end
		WorldMapFrame:HookScript("OnShow", UpdateWorldPin)
		WorldMapFrame:HookScript("OnHide", function() if worldPin then worldPin:Hide() end end)
	end
	UpdateWorldPin()
	if t.coords then ns.Print(t.title .. ": " .. t.coords) end
end

-- ------------------------------------------------------------------ popup with drawn map
local pop
local MAPW = 600

local function CreatePopup()
	local f = CreateFrame("Frame", "StandardsGuidesAtlasFrame", UIParent)
	f:SetSize(MAPW + 30, 520)
	f:SetPoint("CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	ns.Skin(f, C.bg, C.line, 0.98)
	tinsert(UISpecialFrames, "StandardsGuidesAtlasFrame")

	f.title = f:CreateFontString(nil, "OVERLAY")
	f.title:SetFontObject(ns.F.h3)
	f.title:SetPoint("TOPLEFT", 15, -14)
	f.title:SetPoint("RIGHT", -100, 0)
	f.sub = f:CreateFontString(nil, "OVERLAY")
	f.sub:SetFontObject(ns.F.small)
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
	f.sub:SetPoint("RIGHT", -15, 0)
	f.sub:SetJustifyH("LEFT")
	local close = ns.Button(f, "Close", 70, 22, function() f:Hide() end)
	close:SetPoint("TOPRIGHT", -12, -12)

	local clip = CreateFrame("Frame", nil, f)
	clip:SetPoint("TOPLEFT", 15, -64)
	clip:SetSize(MAPW, MAPW * 2 / 3)
	clip:SetClipsChildren(true)
	ns.Skin(clip, C.inset, C.line)
	f.clip = clip
	local canvas = CreateFrame("Frame", nil, clip)
	canvas:SetPoint("TOPLEFT")
	canvas:SetSize(MAPW, MAPW * 2 / 3)
	f.canvas = canvas
	f.tiles = {}
	f.pin = MakePin(canvas, 18)
	f.msg = clip:CreateFontString(nil, "OVERLAY")
	f.msg:SetFontObject(ns.F.body)
	f.msg:SetPoint("CENTER")
	f.msg:SetWidth(MAPW - 60)
	f.msg:SetJustifyH("CENTER")

	f.coords = f:CreateFontString(nil, "OVERLAY")
	f.coords:SetFontObject(ns.F.body)
	f.coords:SetPoint("TOPLEFT", clip, "BOTTOMLEFT", 0, -10)
	f.coords:SetPoint("RIGHT", -15, 0)
	f.coords:SetJustifyH("LEFT")

	f.zoneBtn = ns.Button(f, "Zone", 80, 22)
	f.zoneBtn:SetPoint("BOTTOMLEFT", 15, 14)
	f.contBtn = ns.Button(f, "Continent", 90, 22)
	f.contBtn:SetPoint("LEFT", f.zoneBtn, "RIGHT", 6, 0)
	f.worldBtn = ns.Button(f, "Show on world map", 150, 22)
	f.worldBtn:SetPoint("LEFT", f.contBtn, "RIGHT", 6, 0)
	f.worldBtn.tip = "Opens the world map at this spot and pins it there."
	local foot = f:CreateFontString(nil, "OVERLAY")
	foot:SetFontObject(ns.F.small)
	foot:SetPoint("BOTTOMRIGHT", -15, 18)
	foot:SetText("Positions: Forever Atlas (atlas.standards.gg)")
	return f
end

local function DrawMap(f, mapID, px, py)
	for _, t in ipairs(f.tiles) do t:Hide() end
	f.msg:SetText("")
	f.pin:Hide()
	local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
	local L = layers and layers[1]
	local textures = L and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
	if not L or not textures or #textures == 0 then
		f.msg:SetText("This client cannot draw the map here. Use \"Show on world map\".")
		return
	end
	local scale = MAPW / L.layerWidth
	local h = L.layerHeight * scale
	f.clip:SetHeight(h)
	f.canvas:SetSize(MAPW, h)
	f:SetHeight(h + 64 + 90)
	local cols = math.ceil(L.layerWidth / L.tileWidth)
	local rows = math.ceil(L.layerHeight / L.tileHeight)
	local tw, th = L.tileWidth * scale, L.tileHeight * scale
	local i = 0
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			i = i + 1
			local t = f.tiles[i]
			if not t then t = f.canvas:CreateTexture(nil, "ARTWORK"); f.tiles[i] = t end
			t:SetTexture(textures[i])
			t:SetSize(tw, th)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", f.canvas, "TOPLEFT", c * tw, -r * th)
			t:Show()
		end
	end
	if px then
		f.pin:ClearAllPoints()
		f.pin:SetPoint("CENTER", f.canvas, "TOPLEFT", px * MAPW, -py * h)
		f.pin:Show()
	end
end

local function MapName(id)
	local info = id and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
	return info and info.name
end

-- t = { title, sub, c, x, y, noPos }
local function Show(t)
	pop = pop or CreatePopup()
	pop.title:SetText(t.title)
	pop.sub:SetText(t.sub or "")
	local zone, zx, zy, cont, cx, cy = Resolve(t.c, t.x, t.y)
	if not zone then
		DrawMap(pop, nil)
		pop.msg:SetText(t.x and "This client did not return a map position for these coordinates." or
			"The Atlas does not have a map position for this yet.")
		pop.coords:SetText("")
		pop.zoneBtn:Hide(); pop.contBtn:Hide(); pop.worldBtn:Hide()
		pop:Show()
		return
	end
	local zname = MapName(zone) or "Map"
	t.coords = ("%s %.1f, %.1f"):format(zname, zx * 100, zy * 100)
	t.zone, t.zx, t.zy, t.cont, t.cx, t.cy = zone, zx, zy, cont, cx, cy
	pop.coords:SetText("|cff" .. ns.Hex(C.gold) .. zname .. "|r  " .. ("%.1f, %.1f"):format(zx * 100, zy * 100))
	pop.zoneBtn:Show(); pop.contBtn:Show(); pop.worldBtn:Show()
	pop.zoneBtn:SetScript("OnClick", function()
		DrawMap(pop, zone, zx, zy); pop.zoneBtn:SetActive(true); pop.contBtn:SetActive(false)
	end)
	pop.contBtn:SetScript("OnClick", function()
		DrawMap(pop, cont, cx, cy); pop.zoneBtn:SetActive(false); pop.contBtn:SetActive(true)
	end)
	pop.worldBtn:SetScript("OnClick", function() ns.PinOnWorldMap(t) end)
	pop.contBtn:SetShown(cont ~= zone)
	DrawMap(pop, zone, zx, zy)
	pop.zoneBtn:SetActive(true); pop.contBtn:SetActive(false)
	pop:Show()
end

function ns.ShowDungeonAtlas(name)
	local d = ns.AtlasPlace(name)
	if not d then return end
	local sub = {}
	if d.z then sub[#sub + 1] = d.z end
	if d.l then sub[#sub + 1] = "level " .. d.l end
	if d.g ~= d.n and d.g:find(d.n, 1, true) ~= 1 then sub[#sub + 1] = "Atlas lists it as " .. d.n
	elseif d.g ~= d.n then sub[#sub + 1] = "entrance shared with the whole " .. d.n end
	Show({ title = name, sub = table.concat(sub, " · "), c = d.c, x = d.x, y = d.y })
end

function ns.ShowQuestAtlas(cls, key)
	local e = cls.quests and cls.quests[key]
	if not e then return end
	local t = { title = "Quest: " .. e.q }
	local sub = {}
	if e.k == "dungeon" then
		local d = ns.AtlasPlaces[e.d]
		if not d then return end
		t.c, t.x, t.y = d.c, d.x, d.y
		sub[#sub + 1] = e.npc .. " · " .. (d.z or "") .. " (" .. d.n .. ")"
	else
		t.c, t.x, t.y = e.c, e.x, e.y
		sub[#sub + 1] = e.npc .. " · " .. (e.w or "")
	end
	if e.note then sub[#sub + 1] = e.note end
	t.sub = table.concat(sub, " · ")
	Show(t)
end
