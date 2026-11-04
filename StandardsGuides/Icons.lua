-- Standards.gg Field Guides: spell and talent icons from the game client.
-- The guides name spells but carry no spell IDs, and the client only resolves spell names the
-- character knows. Unknown names are found by a background scan of the client's spell table
-- (a few milliseconds per frame), and the results are saved per game build so the scan runs once.
local _, ns = ...

local QUESTION = 134400 -- INV_Misc_QuestionMark
local GetSpellTex = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local LegacyInfo = GetSpellInfo
local InfoC = C_Spell and C_Spell.GetSpellInfo

-- name and icon of a spell ID (nil when the ID does not exist)
local function InfoByID(id)
	if LegacyInfo then
		local name, _, icon = LegacyInfo(id)
		return name, icon
	end
	local i = InfoC(id)
	if i then return i.name, i.iconID end
end
local canScan = (LegacyInfo or InfoC) and debugprofilestop and C_Timer and true

local MAX_ID = 1500000   -- covers Classic, Season and Forever-era spell IDs
local CHUNK = 250
local BUDGET_MS = 3      -- per frame

local store              -- saved: { build, spells = { [key] = { icon, id } }, miss = { [key] = true } }
local wanted, wantedCount = {}, 0
local scanning, nextId = false, 1
local refreshQueued = false

local function Store()
	if store then return store end
	if not ns.db then return nil end
	local build = select(2, GetBuildInfo())
	local s = ns.db.icons
	if not s or s.build ~= build then
		s = { build = build, spells = {}, miss = {} }
		ns.db.icons = s
	end
	store = s
	return s
end

-- Re-render the open page once new icons arrive (at most once a second).
local function Refresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(1, function()
		refreshQueued = false
		local m = ns.main
		if not (m and m:IsShown()) then return end
		if m.guide:IsShown() and m.guide.Rerender then m.guide:Rerender() end
	end)
end
ns.RefreshIcons = Refresh

-- wanted[key] = number of spell IDs still to check for that name; the scan wraps around so a
-- name added mid-scan is still checked against every ID once.
local function Step()
	local s = Store()
	local t0 = debugprofilestop()
	local id, found, covered = nextId, false, 0
	repeat
		for i = id, id + CHUNK - 1 do
			local name, icon = InfoByID(i)
			if name and icon then
				local k = ns.Key(name)
				if wanted[k] then
					s.spells[k] = { icon, i }
					wanted[k] = nil
					wantedCount = wantedCount - 1
					found = true
				end
			end
		end
		id = id + CHUNK
		covered = covered + CHUNK
		if id > MAX_ID then id = 1 end
	until wantedCount == 0 or debugprofilestop() - t0 > BUDGET_MS
	nextId = id
	for k, left in pairs(wanted) do
		left = left - covered
		if left <= 0 then
			s.miss[k] = true -- not in this client: don't search again this build
			wanted[k] = nil
			wantedCount = wantedCount - 1
		else
			wanted[k] = left
		end
	end
	if found then Refresh() end
	if wantedCount <= 0 then
		wantedCount, scanning = 0, false
		return
	end
	C_Timer.After(0, Step)
end

local function Want(k)
	if wanted[k] or not canScan then return end
	wanted[k] = MAX_ID
	wantedCount = wantedCount + 1
	if not scanning then
		scanning = true
		C_Timer.After(0, Step)
	end
end

-- Icon (and spell ID when known) for a spell or talent name; a question mark until it is found.
function ns.SpellIcon(name)
	if not name or name == "" then return QUESTION end
	local s = Store()
	local k = ns.Key(name)
	local hit = s and s.spells[k]
	if hit then return hit[1], hit[2] end
	if GetSpellTex then
		local ok, tex = pcall(GetSpellTex, name)
		if ok and tex then
			if s then s.spells[k] = { tex } end
			return tex
		end
	end
	if s and not s.miss[k] then Want(k) end
	return QUESTION
end

-- Queues every spell and talent name a class's guides show, so their icons are ready before the guide opens.
function ns.QueueClassIcons(cls)
	for _, spec in ipairs(cls.specs) do
		for _, b in ipairs(spec.blocks or {}) do
			if b.t == "abil" then
				for _, n in ipairs(b.names) do ns.SpellIcon(n) end
			elseif b.t == "macro" and ns.MacroSpell then
				local n = ns.MacroSpell(b.code or "")
				if n then ns.SpellIcon(n) end
			end
		end
		for _, r in ipairs(spec.ranks or {}) do ns.SpellIcon(r.name) end
	end
end

-- A few seconds after login (out of combat), load your class's guide data and start its icon lookup,
-- so the first /sgg me opens without the one-time load.
function ns.Prewarm()
	if InCombatLockdown and InCombatLockdown() then
		C_Timer.After(10, ns.Prewarm)
		return
	end
	local _, token = UnitClass("player")
	local cls = token and ns.GetClassData(token:lower())
	if cls then ns.QueueClassIcons(cls) end
end

-- Spell tooltip from the client when the spell ID is known, otherwise the name alone.
function ns.SpellTooltip(owner, name, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
	local _, id = ns.SpellIcon(name)
	if id and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, id) then
		GameTooltip:Show()
		return
	end
	GameTooltip:AddLine(name, 1, 1, 1)
	GameTooltip:Show()
end
