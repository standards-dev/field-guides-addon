-- Standards.gg Field Guides: pooled layout engine and scroll frame.
-- Every guide page is drawn top-to-bottom into one scroll child; widgets come from pools
-- and go back on each re-render, so filtering or switching guides creates no new frames.
local _, ns = ...

local FONT_COLOR = {}
local function fontColor(font)
	if FONT_COLOR[font] then return FONT_COLOR[font] end
	local r, g, b = font:GetTextColor()
	FONT_COLOR[font] = { r, g, b }
	return FONT_COLOR[font]
end

-- Performance notes (in-game):
--  * Widgets only stay shown while they are within one screen of the visible part of the page
--    (Layout:Cull, run after every render and scroll); everything else is hidden, so the client
--    lays out and draws a few hundred regions instead of thousands.
--  * Each pooled widget remembers its font, colour, justification and texture state, so a re-render
--    only sends the API calls that actually change something.
--  * Text heights are cached by font + width + text, so re-rendering after a filter change does not
--    force the client to re-measure every paragraph.
local Layout = {}
Layout.__index = Layout

local heightCache, heightCount = {}, 0
local function cachedHeight(font, width, text)
	local byFont = heightCache[font]
	if not byFont then byFont = {}; heightCache[font] = byFont end
	local byWidth = byFont[width]
	if not byWidth then byWidth = {}; byFont[width] = byWidth end
	return byWidth, byWidth[text]
end

function ns.NewLayout(content)
	local lay = setmetatable({ content = content, pools = {}, used = {}, y = 0, anchors = {}, search = {} }, Layout)
	content.sggLayout = lay
	return lay
end

-- Takes a widget from its pool and records the page band (y .. y + h) it occupies.
-- Widgets start hidden; Cull shows the ones near the viewport.
function Layout:Acquire(kind, create, y, h)
	local pool = self.pools[kind]
	if not pool then pool = {}; self.pools[kind] = pool end
	local o = table.remove(pool)
	if not o then
		o = create(self.content)
		o:Hide()
		o.sggVis = false
	end
	o.sggKind = kind
	o.sggY1, o.sggY2 = y or 0, (y or 0) + (h or 0)
	self.used[#self.used + 1] = o
	o:ClearAllPoints()
	return o
end

-- Updates the band of a widget that the caller moved after placing it.
function Layout:Move(o, y, h)
	o.sggY1, o.sggY2 = y, y + h
end

function Layout:Reset()
	local used = self.used
	for i = 1, #used do
		local o = used[i]
		if o.sggVis then o:Hide(); o.sggVis = false end
		if o.OnRelease then o:OnRelease() end
		local pool = self.pools[o.sggKind]
		pool[#pool + 1] = o
		used[i] = nil
	end
	wipe(self.anchors)
	wipe(self.search)
	if self.deferred then wipe(self.deferred) end
	self.y = 0
end

-- Height of a text block without placing a widget (cached like Layout:Text).
function Layout:Measure(font, text, width)
	local byWidth, h = cachedHeight(font, width, text)
	if h then return h end
	local m = self.measurer
	if not m then
		m = self.content:CreateFontString(nil, "ARTWORK")
		m:SetWordWrap(true)
		m:SetNonSpaceWrap(true)
		m:Hide()
		self.measurer = m
	end
	m:SetFontObject(font)
	m:SetWidth(width)
	m:SetHeight(0)
	m:SetText(text)
	h = m:GetStringHeight()
	byWidth[text] = h
	heightCount = heightCount + 1
	return h
end

-- Reserves a band of the page and builds its widgets only when it first comes near the view.
-- build() places widgets with the usual Layout methods; their text is not added to the search
-- index again (callers index it up front with Layout:Index).
function Layout:Defer(y, h, build)
	self.deferred = self.deferred or {}
	self.deferred[#self.deferred + 1] = { y, y + h, build }
end

function Layout:Index(text, x, y, w, h)
	if text and text ~= "" then self.search[#self.search + 1] = { y = y, h = h, x = x, w = w, raw = text } end
end

-- Shows widgets within one viewport-height of [top, bottom] and hides the rest.
function Layout:Cull(top, bottom)
	local margin = math.max(200, bottom - top)
	local lo, hi = top - margin, bottom + margin
	self.cullTop, self.cullBottom = top, bottom
	local d = self.deferred
	if d then
		self.noIndex = true
		for i = 1, #d do
			local band = d[i]
			if band[3] and band[2] >= lo and band[1] <= hi then
				local build = band[3]
				band[3] = nil
				build()
			end
		end
		self.noIndex = nil
	end
	local used = self.used
	for i = 1, #used do
		local o = used[i]
		local vis = o.sggY2 >= lo and o.sggY1 <= hi
		if vis ~= o.sggVis then
			o.sggVis = vis
			if vis then o:Show() else o:Hide() end
		end
	end
end

-- Re-culls on scroll only once the view has moved a third of a screen since the last pass.
function Layout:ScrollCull(top, bottom)
	local last = self.cullTop
	if last and math.abs(top - last) < (bottom - top) / 3 and math.abs((bottom - top) - (self.cullBottom - last)) < 1 then return end
	self:Cull(top, bottom)
end

local function newFS(content)
	local fs = content:CreateFontString(nil, "ARTWORK")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetNonSpaceWrap(true)
	return fs
end
local function newTex(content) return content:CreateTexture(nil, "BACKGROUND") end
local function newTexArt(content) return content:CreateTexture(nil, "BORDER") end
local function newEdge(content) return content:CreateTexture(nil, "BACKGROUND", nil, -8) end

-- Places a wrapped FontString at (x, -y) and returns it with its height.
function Layout:Text(font, text, x, y, width, color, justify)
	text = text or ""
	local byWidth, h = cachedHeight(font, width, text)
	local fs = self:Acquire("fs", newFS, y, h or 0)
	if fs.sggFont ~= font then fs:SetFontObject(font); fs.sggFont = font; fs.sggColor = nil end
	local c = color or fontColor(font)
	if fs.sggColor ~= c then fs:SetTextColor(c[1], c[2], c[3]); fs.sggColor = c end
	justify = justify or "LEFT"
	if fs.sggJustify ~= justify then fs:SetJustifyH(justify); fs.sggJustify = justify end
	fs:SetWidth(width)
	if h then
		fs:SetText(text)
	else
		fs:SetHeight(0)
		fs:SetText(text)
		h = fs:GetStringHeight()
		byWidth[text] = h
		heightCount = heightCount + 1
		if heightCount > 20000 then wipe(heightCache); heightCount = 0 end
		fs.sggY2 = y + h
	end
	fs:SetHeight(h)
	fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	if text ~= "" and not self.noIndex then
		self.search[#self.search + 1] = { fs = fs, y = y, h = h, x = x, w = width, raw = text } -- lower-cased lazily by the search
	end
	return fs, h
end

local function resetImage(t)
	if t.sggImg then
		t:SetTexCoord(0, 1, 0, 1)
		t:SetDesaturated(false)
		t:SetVertexColor(1, 1, 1, 1)
		t.sggImg = nil
	end
end

function Layout:Rect(x, y, w, h, color, alpha, art)
	local t = self:Acquire(art and "texart" or "tex", art and newTexArt or newTex, y, h)
	resetImage(t)
	t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	t:SetSize(w, h)
	t:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	return t
end

function Layout:Image(x, y, w, h, texture)
	local t = self:Acquire("texart", newTexArt, y, h)
	resetImage(t)
	t:SetTexture(texture)
	t.sggImg = true -- callers may tint or crop it; reset on next use
	t:SetSize(w, h)
	t:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	return t
end

-- Bordered panel: one edge texture under one background texture inset by 1px (2 textures instead of 5).
function Layout:Box(x, y, w, h, bg, border, bar)
	local b = border or ns.C.line
	local e = self:Acquire("edge", newEdge, y, h)
	e:SetColorTexture(b[1], b[2], b[3], 1)
	e:SetSize(w, h)
	e:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	self:Rect(x + 1, y + 1, w - 2, h - 2, bg or ns.C.panel, 1)
	if bar then self:Rect(x, y, 3, h, bar, 1, true) end
end

-- Pooled flat button placed in the content.
local function newButton(content)
	local b = ns.Button(content, "", 100, 22)
	b.OnRelease = function(self)
		self:SetScript("OnClick", nil)
		self.tip = nil
		if self.active then self:SetActive(false) end
	end
	return b
end

function Layout:Button(x, y, w, h, label, onClick, tip)
	local b = self:Acquire("button", newButton, y, h)
	b:SetSize(w, h)
	b:SetLabel(label)
	b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	b:SetScript("OnClick", onClick)
	b.tip = tip
	return b
end

-- Transparent click area over drawn content (collapsible headers).
local function newHit(content)
	local b = CreateFrame("Button", nil, content)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.04)
	b.OnRelease = function(self) self:SetScript("OnClick", nil) end
	return b
end

function Layout:Hit(x, y, w, h, onClick)
	local b = self:Acquire("hit", newHit, y, h)
	b:SetSize(w, h)
	b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	b:SetScript("OnClick", onClick)
	return b
end

-- Icon button with tooltip handler (items, talents, abilities).
local function newIcon(content)
	local b = CreateFrame("Button", nil, content)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	-- 1px frame: one texture behind the icon, 1px larger on every side
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetPoint("TOPLEFT", -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
	b.count = b:CreateFontString(nil, "OVERLAY")
	b.count:SetFont(ns.FONT.bold, 10, "OUTLINE")
	b.count:SetPoint("BOTTOMRIGHT", 2, -2)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b.OnRelease = function(self)
		self:SetScript("OnEnter", nil)
		self:SetScript("OnClick", nil)
		if self.sggTinted then
			self.icon:SetDesaturated(false)
			self.icon:SetVertexColor(1, 1, 1)
			self.sggTinted = nil
		end
		if self.sggCount then self.count:SetText(""); self.sggCount = nil end
		self.data = nil
	end
	function b:SetBorder(c)
		if self.sggEdge ~= c then self.edge:SetColorTexture(c[1], c[2], c[3], 1); self.sggEdge = c end
	end
	return b
end

function Layout:Icon(x, y, size, texture, borderColor)
	local b = self:Acquire("icon", newIcon, y, size)
	b:SetSize(size, size)
	texture = texture or 134400
	if b.sggTex ~= texture then b.icon:SetTexture(texture); b.sggTex = texture end
	b:SetBorder(borderColor or ns.C.line)
	b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	-- callers tint or label icons after placing them; remember to undo it on release
	b.sggTinted, b.sggCount = true, true
	return b
end

-- Persistent (not pooled) frame placed at a position; used for search boxes and the notes editor.
function Layout:Place(frame, x, y)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
	frame:Show()
	self.placed = self.placed or {}
	self.placed[frame] = true
end

function Layout:HidePlaced()
	if not self.placed then return end
	for f in pairs(self.placed) do f:Hide() end
	wipe(self.placed)
end

-- ------------------------------------------------------------------ scroll frame with a slim bar
function ns.ScrollArea(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(10, 10)
	sf:SetScrollChild(content)
	sf.content = content

	local bar = CreateFrame("Slider", nil, sf)
	bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 10, 0)
	bar:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 10, 0)
	bar:SetWidth(6)
	bar:SetOrientation("VERTICAL")
	bar:SetMinMaxValues(0, 1)
	bar:SetValueStep(1)
	bar:SetObeyStepOnDrag(false)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(ns.C.line[1], ns.C.line[2], ns.C.line[3], 0.5)
	local thumb = bar:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(ns.C.gold[1], ns.C.gold[2], ns.C.gold[3], 0.8)
	thumb:SetSize(6, 40)
	bar:SetThumbTexture(thumb)
	sf.bar = bar

	local updating
	bar:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		sf:SetVerticalScroll(v)
	end)
	-- keep only the widgets near the visible band shown (see Layout:Cull)
	sf:SetScript("OnVerticalScroll", function(self, v)
		local lay = content.sggLayout
		if lay then lay:ScrollCull(v, v + self:GetHeight()) end
	end)
	function sf:UpdateRange()
		local max = math.max(0, content:GetHeight() - self:GetHeight())
		updating = true
		bar:SetMinMaxValues(0, max)
		bar:SetValue(math.min(self:GetVerticalScroll(), max))
		updating = false
		bar:SetShown(max > 0)
		local ratio = self:GetHeight() / math.max(1, content:GetHeight())
		thumb:SetHeight(math.max(30, self:GetHeight() * math.min(1, ratio)))
		local lay = content.sggLayout
		if lay then local top = self:GetVerticalScroll(); lay:Cull(top, top + self:GetHeight()) end
	end
	function sf:ScrollTo(y)
		local max = math.max(0, content:GetHeight() - self:GetHeight())
		y = math.max(0, math.min(max, y))
		self:SetVerticalScroll(y)
		updating = true
		bar:SetValue(y)
		updating = false
	end
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		self:ScrollTo(self:GetVerticalScroll() - delta * 60)
	end)
	sf:SetScript("OnSizeChanged", function(self) self:UpdateRange() end)
	return sf
end
