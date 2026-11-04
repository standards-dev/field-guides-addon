-- Standards.gg Field Guides: hub (the Field Guides home page: 3 x 3 class cards with spec buttons).
-- Layout follows the site's hub card for card; colours use the WoW UI palette.
local _, ns = ...
local C = ns.C

local ART = "Interface\\AddOns\\StandardsGuides\\Art\\"

function ns.CreateHub(main)
	local hub = CreateFrame("Frame", nil, main)
	hub:SetPoint("TOPLEFT", 1, -65)
	hub:SetPoint("BOTTOMRIGHT", -1, 1)

	-- header: logo + wordmark in a bordered box, then the section label (the site's link to standards.gg is not carried over)
	local head = CreateFrame("Frame", nil, hub)
	head:SetPoint("TOPLEFT", main.bar, "TOPLEFT")
	head:SetPoint("BOTTOMRIGHT", main.bar, "BOTTOMRIGHT", -44, 0)
	head:SetFrameLevel(main.bar:GetFrameLevel() + 2)
	local box = CreateFrame("Frame", nil, head)
	box:SetPoint("LEFT", 22, 0)
	box:SetHeight(48)
	ns.Skin(box, C.bg, C.line, 0)
	local logo = box:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(ART .. "mark")
	logo:SetSize(40, 40)
	logo:SetPoint("LEFT", 8, 0)
	local mark = box:CreateFontString(nil, "OVERLAY")
	mark:SetFontObject(ns.F.mark)
	mark:SetPoint("LEFT", logo, "RIGHT", 12, 0)
	mark:SetText("STANDARDS|cffffd100.GG|r")
	box:SetWidth(8 + 40 + 12 + mark:GetStringWidth() + 16)
	local sub = head:CreateFontString(nil, "OVERLAY")
	sub:SetFont(ns.FONT.bold, 11, "")
	sub:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	sub:SetPoint("LEFT", box, "RIGHT", 18, 0)
	sub:SetText(ns.Track("WoW Forever · Field Guides"))

	local sf = ns.ScrollArea(hub)
	sf:SetPoint("TOPLEFT", 0, 0)
	sf:SetPoint("BOTTOMRIGHT", -14, 0)
	local content = sf.content
	local lay = ns.NewLayout(content)

	local PAD = 22
	local cards = {}

	-- one class card: dark-to-clear wash over the character art on the right, name, subtitle, stacked spec buttons
	local function Card(i, cinfo, x, y, w, h)
		local card = cards[i]
		if not card then
			card = CreateFrame("Button", nil, content)
			ns.Skin(card, C.panel, C.line, 0.88)
			card.art = card:CreateTexture(nil, "BACKGROUND", nil, 1)
			card.art:SetPoint("BOTTOMRIGHT", -8, 0)
			-- the site's card::before wash: opaque on the left, clear by 72%
			card.wash1 = card:CreateTexture(nil, "BORDER", nil, -1)
			card.wash1:SetPoint("TOPLEFT", 1, -1)
			card.wash1:SetPoint("BOTTOMLEFT", 1, 1)
			card.wash2 = card:CreateTexture(nil, "BORDER", nil, -1)
			card.wash2:SetPoint("TOPLEFT", card.wash1, "TOPRIGHT")
			card.wash2:SetPoint("BOTTOMLEFT", card.wash1, "BOTTOMRIGHT")
			local p = C.panel
			ns.Gradient(card.wash1, "HORIZONTAL", p[1], p[2], p[3], 0.96, p[1], p[2], p[3], 0.82)
			ns.Gradient(card.wash2, "HORIZONTAL", p[1], p[2], p[3], 0.82, p[1], p[2], p[3], 0)
			card.name = card:CreateFontString(nil, "OVERLAY")
			card.name:SetFontObject(ns.F.card)
			card.name:SetPoint("TOPLEFT", PAD, -PAD)
			card.choose = card:CreateFontString(nil, "OVERLAY")
			card.choose:SetFont(ns.FONT.body, 14, "")
			card.choose:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			card.choose:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -8)
			card.choose:SetText("Choose a specialization")
			card.specs = {}
			card:SetScript("OnEnter", function(self)
				for k = 1, 4 do self.sggBorder[k]:SetColorTexture(C.metal[1], C.metal[2], C.metal[3]) end
				self.art:SetAlpha(1)
			end)
			card:SetScript("OnLeave", function(self)
				for k = 1, 4 do self.sggBorder[k]:SetColorTexture(C.line[1], C.line[2], C.line[3]) end
				self.art:SetAlpha(0.9)
			end)
			cards[i] = card
		end
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
		card:SetSize(w, h)
		card.wash1:SetWidth(math.floor((w - 2) * 0.38))
		card.wash2:SetWidth(math.floor((w - 2) * 0.34))

		-- art: shown at its own resolution or smaller (CSS "contain" in a 62% x (h - 10) box), never stretched
		local a = cinfo.art
		if a then
			local aw, ah = w * 0.62, h - 10
			local s = math.min(aw / a.w, ah / a.h, 1)
			card.art:SetTexture(ART .. cinfo.key)
			card.art:SetTexCoord(0, a.w / a.tw, 0, a.h / a.th)
			card.art:SetSize(math.floor(a.w * s + 0.5), math.floor(a.h * s + 0.5))
			card.art:SetAlpha(0.9)
			card.art:Show()
		else
			card.art:Hide()
		end

		-- class name in the class colour (WoW palette)
		local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cinfo.key:upper()]
		card.name:SetText(cinfo.name)
		if cc then card.name:SetTextColor(cc.r, cc.g, cc.b) else card.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
		card:SetScript("OnClick", function() ns.OpenGuide(cinfo.key, cinfo.specs[1].id) end)

		-- spec buttons stacked in a column, outline style
		for _, b in ipairs(card.specs) do b:Hide() end
		local by = PAD + 30 + 8 + 20 + 14
		for k, s in ipairs(cinfo.specs) do
			local b = card.specs[k]
			if not b then
				b = ns.Button(card, "", 80, 32)
				b.text:SetFontObject(ns.F.spec)
				b:SetFlat(true, C.muted)
				card.specs[k] = b
			end
			b:SetLabel(s.name)
			b:SetWidth(math.ceil(b.text:GetStringWidth()) + 26)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -by)
			b:SetScript("OnClick", function() ns.OpenGuide(cinfo.key, s.id) end)
			b.tip = nil
			b:Show()
			by = by + 32 + 8
		end
		card:Show()
	end

	local function CardHeight(cinfo)
		return math.max(270, PAD + 30 + 8 + 20 + 14 + #cinfo.specs * 40 - 8 + PAD)
	end

	function hub:Render()
		lay:Reset()
		local W = sf:GetWidth()
		content:SetWidth(W)
		local x, w = 28, W - 56
		local y = 40
		local _, h = lay:Text(ns.F.kicker, ns.Track("WoW Forever · Level 1 to 60"), x, y, w)
		y = y + h + 12
		_, h = lay:Text(ns.F.h1, "Class field guides", x, y, w)
		y = y + h + 12
		_, h = lay:Text(ns.F.lede, "Talent builds, leveling routes, rotations, gear, dungeon loot, professions and macros for every specialization.", x, y, math.min(w, 640))
		y = y + h + 30
		local gap = 16
		local cw = math.floor((w - gap * 2) / 3)
		local classes = ns.Hub.classes
		for row = 0, math.ceil(#classes / 3) - 1 do
			local ch = 0
			for col = 1, 3 do
				local c = classes[row * 3 + col]
				if c then ch = math.max(ch, CardHeight(c)) end
			end
			for col = 1, 3 do
				local i = row * 3 + col
				if classes[i] then Card(i, classes[i], x + (col - 1) * (cw + gap), y, cw, ch) end
			end
			y = y + ch + gap
		end

		-- "Using these guides" box (the site's .fg-reuse: gold bar on the left)
		y = y + 24
		local bx, bw = x + 27, w - 54
		local yy = y + 24
		local _, h2 = lay:Text(ns.F.card, "Using these guides", bx, yy, bw, C.white)
		yy = yy + h2 + 10
		local body = {
			"You are welcome to read, share and link to the Standards.gg Field Guides.",
			"Anyone who collects content or data from these guides must credit |cffffffffStandards.gg|r and link to standards.gg/field-guides (or the guide page they used) in any content they create with it. This covers text, talent builds, stat priorities, item and loot lists, screenshots and recordings, datasets, and use in AI training or AI-generated answers.",
		}
		for _, t in ipairs(body) do
			local _, th = lay:Text(ns.F.body, t, bx, yy, math.min(bw, 760), C.muted)
			yy = yy + th + 10
		end
		local _, lh = lay:Text(ns.F.kicker, ns.Track("Credit line"), bx, yy + 9, 120)
		local cx = bx + 110
		local _, crh = lay:Text(ns.F.code, ns.CREDIT, cx + 10, yy + 6, bw - 120, C.white)
		lay:Rect(cx, yy, math.min(bw - 110, 470), crh + 12, { 0, 0, 0 }, 0.45, true)
		yy = yy + crh + 12 + 24
		lay:Box(x, y, w, yy - y, C.panel, C.line, C.gold)
		y = yy + 30
		local _, nh = lay:Text(ns.F.small, "Class artwork: World of Warcraft Fan Site Kit. World of Warcraft® and Blizzard Entertainment® are all trademarks or registered trademarks of Blizzard Entertainment in the United States and/or other countries. These terms and all related materials, logos, and images are copyright © Blizzard Entertainment. This addon is in no way associated with or endorsed by Blizzard Entertainment®.", x, y, w, C.dim)
		y = y + nh + 18
		_, h = lay:Text(ns.F.small, "/sgg opens this window · /sgg me opens your class guide · /sgg help lists commands", x, y, w, C.dim, "CENTER")
		y = y + h + 28
		content:SetHeight(y)
		sf:UpdateRange()
	end

	hub:SetScript("OnShow", function(self) self:Render() end)
	return hub
end
