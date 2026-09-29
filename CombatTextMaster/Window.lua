local _, ns = ...

local ROW = 26
local GAP = 8
local PAD = 14
local CONTENT = 344
local COLLAPSED = 48

local window
local lookPage
local alertPage
local lookButton
local alertButton
local previewOverpower
local previewDamage
local previewIcon
local faceButtons = {}
local outlineButtons = {}
local sizeText
local alertRows = {}
local classHeaders = {}
local emptyText
local expandedID
local page = "look"

local OUTLINE_LABELS = {
	NONE = "None",
	OUTLINE = "Thin",
	THICKOUTLINE = "Thick",
}

local function SavePosition()
	if not window then
		return
	end
	local point, _, relativePoint, x, y = window:GetPoint(1)
	if not point then
		return
	end
	CombatTextMasterDB.point = point
	CombatTextMasterDB.relativePoint = relativePoint
	CombatTextMasterDB.x = x
	CombatTextMasterDB.y = y
end

local function RestorePosition()
	window:ClearAllPoints()
	local db = CombatTextMasterDB
	if type(db.point) == "string" and type(db.x) == "number" and type(db.y) == "number" then
		window:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x, db.y)
	else
		window:SetPoint("CENTER", UIParent, "CENTER", 280, 40)
	end
end

local function ApplyPreviewFont(fs, large)
	local flags = ns.FontFlags()
	local size = ns.FontSize(large)
	if not fs:SetFont(ns.FontFile(), size, flags) then
		fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
	end
end

function ns.RefreshPreview()
	if not previewOverpower then
		return
	end
	ApplyPreviewFont(previewOverpower, true)
	ApplyPreviewFont(previewDamage, false)
	local sample = ns.ALERTS[1]
	previewOverpower:SetText("<" .. ns.AlertName(sample) .. ">")
	previewOverpower:SetTextColor(1, 0.82, 0)
	previewDamage:SetText("-123")
	previewDamage:SetTextColor(1, 0.1, 0.1)
	if previewIcon then
		previewIcon:SetTexture(ns.AlertIcon(sample))
	end
end

local function PaintChoice(button, selected)
	if selected then
		button:SetNormalFontObject("GameFontHighlight")
	else
		button:SetNormalFontObject("GameFontNormal")
	end
end

local function PaintChoices()
	local face = CombatTextMasterDB.fontFace
	for i = 1, #faceButtons do
		PaintChoice(faceButtons[i], faceButtons[i].faceKey == face)
	end
	local outline = CombatTextMasterDB.outline
	for i = 1, #outlineButtons do
		PaintChoice(outlineButtons[i], outlineButtons[i].outlineKey == outline)
	end
	if sizeText then
		sizeText:SetText(tostring(ns.FontSize(false)))
	end
	PaintChoice(lookButton, page == "look")
	PaintChoice(alertButton, page == "alerts")
end

local function ChooseFace(key)
	CombatTextMasterDB.fontFace = key
	ns.RefreshStyle()
	PaintChoices()
end

local function ChooseOutline(outline)
	CombatTextMasterDB.outline = outline
	ns.RefreshStyle()
	PaintChoices()
end

local function ChangeSize(delta)
	local size = ns.FontSize(false) + delta
	if size < 12 then
		size = 12
	end
	if size > 32 then
		size = 32
	end
	CombatTextMasterDB.fontSize = size
	ns.RefreshStyle()
	PaintChoices()
end

function ns.RefreshStyle()
	if ns.RestyleActive then
		ns.RestyleActive()
	end
	ns.RefreshPreview()
end

local function PanelButton(parent, label, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, ROW)
	button:SetText(label)
	return button
end

local function SectionHeader(parent, text, anchor, y)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(18)
	header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
	header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, y)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.text:SetPoint("TOPLEFT", 0, 0)
	header.text:SetJustifyH("LEFT")
	header.text:SetText(text)
	header.text:SetTextColor(1, 0.82, 0)
	header.line = header:CreateTexture(nil, "ARTWORK")
	header.line:SetTexture("Interface\\Common\\UI-TooltipDivider")
	header.line:SetHeight(8)
	header.line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	return header
end

local function ShowArrow(arrow, expanded)
	arrow:SetSize(14, 14)
	local hasAtlas = false
	if C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, "bag-arrow")
		hasAtlas = ok and info ~= nil
	end
	if hasAtlas and arrow.SetAtlas then
		arrow:SetAtlas("bag-arrow")
		if arrow.SetRotation then
			if expanded then
				arrow:SetRotation(math.pi / 2)
			else
				arrow:SetRotation(-math.pi)
			end
		end
	else
		if expanded then
			arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
		else
			arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
		end
		arrow:SetTexCoord(0.2, 0.8, 0.2, 0.8)
		if arrow.SetRotation then
			arrow:SetRotation(0)
		end
	end
end

local function LayoutAlerts()
	for _, header in pairs(classHeaders) do
		header:Hide()
	end
	local y = 0
	local shown = 0
	local lastClass
	for i = 1, #alertRows do
		local row = alertRows[i]
		local alert = row.alert
		if not ns.AlertKnown(alert) then
			row:Hide()
		else
			if alert.class ~= lastClass then
				local header = classHeaders[alert.class]
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", alertPage, "TOPLEFT", 0, -y)
				header:SetPoint("TOPRIGHT", alertPage, "TOPRIGHT", 0, -y)
				header:Show()
				y = y + 22
				lastClass = alert.class
			end
			local open = expandedID == alert.id
			row:Show()
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", alertPage, "TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", alertPage, "TOPRIGHT", 0, -y)
			local detailHeight = 0
			if open then
				row.detail:Show()
				detailHeight = row.detail:GetStringHeight() or 0
				if detailHeight < 28 then
					detailHeight = 28
				end
				detailHeight = detailHeight + 8
			else
				row.detail:Hide()
			end
			row:SetHeight(COLLAPSED + detailHeight)
			row.check:SetChecked(ns.AlertEnabled(alert.id))
			row.name:SetText(ns.AlertName(alert))
			row.blurb:SetText(alert.blurb)
			row.blurb:SetTextColor(0.9, 0.85, 0.7)
			row.icon:SetTexture(ns.AlertIcon(alert))
			ShowArrow(row.arrow, open)
			y = y + COLLAPSED + detailHeight + 6
			shown = shown + 1
		end
	end
	if emptyText then
		if shown == 0 then
			emptyText:Show()
		else
			emptyText:Hide()
		end
	end
end

local function ToggleExpanded(id)
	if expandedID == id then
		expandedID = nil
	else
		expandedID = id
	end
	LayoutAlerts()
end

local function BuildAlertRow(alert)
	local row = CreateFrame("Button", nil, alertPage)
	row.alert = alert
	row:SetHeight(COLLAPSED)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local highlight = row:GetHighlightTexture()
	if highlight then
		highlight:SetAllPoints()
	end

	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("LEFT", 0, 0)
	local builtIn = check.Text or check.text
	if builtIn then
		builtIn:SetText("")
		builtIn:Hide()
	end
	check:SetScript("OnClick", function(self)
		ns.SetAlertEnabled(alert.id, self:GetChecked() and true or false)
		if alert.kind == "cooldown" and ns.WatchCooldowns then
			ns.WatchCooldowns(false)
		end
	end)
	row.check = check

	local slot = row:CreateTexture(nil, "ARTWORK")
	slot:SetSize(36, 36)
	slot:SetPoint("LEFT", check, "RIGHT", 4, 0)
	if slot.SetAtlas then
		slot:SetAtlas("bags-item-slot64")
	end
	local icon = row:CreateTexture(nil, "OVERLAY")
	icon:SetSize(28, 28)
	icon:SetPoint("CENTER", slot, "CENTER")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.icon = icon

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -2)
	name:SetJustifyH("LEFT")
	row.name = name

	local blurb = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	blurb:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
	blurb:SetJustifyH("LEFT")
	row.blurb = blurb

	local arrow = row:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.arrow = arrow

	local detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -6)
	detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	detail:SetJustifyH("LEFT")
	detail:SetJustifyV("TOP")
	detail:SetWordWrap(true)
	detail:SetText(alert.detail)
	detail:SetTextColor(1, 0.95, 0.8)
	detail:Hide()
	row.detail = detail

	row:SetScript("OnClick", function()
		ToggleExpanded(alert.id)
	end)
	alertRows[#alertRows + 1] = row
end

local function ShowPage(which)
	page = which
	if which == "alerts" then
		lookPage:Hide()
		alertPage:Show()
		LayoutAlerts()
	else
		page = "look"
		alertPage:Hide()
		lookPage:Show()
		ns.RefreshPreview()
	end
	PaintChoices()
end

function ns.InitWindow()
	if window then
		return
	end
	ns.InitDB()

	window = CreateFrame("Frame", "CombatTextMasterFrame", UIParent, "ButtonFrameTemplate")
	window:SetFrameStrata("HIGH")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetSize(384, 448)
	window:Hide()
	if window.SetTitle then
		window:SetTitle("Combat Text")
	elseif window.TitleContainer and window.TitleContainer.TitleText then
		window.TitleContainer.TitleText:SetText("Combat Text")
	end
	if window.SetPortraitToAsset then
		window:SetPortraitToAsset("Interface\\Icons\\Ability_MeleeDamage")
	end
	if ButtonFrameTemplate_HideButtonBar then
		ButtonFrameTemplate_HideButtonBar(window)
	end
	if window.CloseButton then
		window.CloseButton:SetScript("OnClick", function()
			window:Hide()
		end)
	end
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	window:SetScript("OnHide", SavePosition)
	if window.TitleContainer then
		window.TitleContainer:EnableMouse(true)
		window.TitleContainer:RegisterForDrag("LeftButton")
		window.TitleContainer:SetScript("OnDragStart", function()
			window:StartMoving()
		end)
		window.TitleContainer:SetScript("OnDragStop", function()
			window:StopMovingOrSizing()
			SavePosition()
		end)
	end
	if UISpecialFrames then
		table.insert(UISpecialFrames, "CombatTextMasterFrame")
	end

	local inset = window.Inset or window
	local nav = CreateFrame("Frame", nil, inset)
	nav:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD, -PAD)
	nav:SetSize(CONTENT, ROW)

	lookButton = PanelButton(nav, "Look", 120)
	lookButton:SetPoint("LEFT", 0, 0)
	lookButton:SetScript("OnClick", function()
		ShowPage("look")
	end)
	alertButton = PanelButton(nav, "Alerts", 120)
	alertButton:SetPoint("LEFT", lookButton, "RIGHT", GAP, 0)
	alertButton:SetScript("OnClick", function()
		ShowPage("alerts")
	end)

	lookPage = CreateFrame("Frame", nil, inset)
	lookPage:SetPoint("TOPLEFT", nav, "BOTTOMLEFT", 0, -12)
	lookPage:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -PAD, PAD)

	local preview = CreateFrame("Frame", nil, lookPage)
	preview:SetPoint("TOPLEFT", lookPage, "TOPLEFT", 0, 0)
	preview:SetPoint("TOPRIGHT", lookPage, "TOPRIGHT", 0, 0)
	preview:SetHeight(64)

	local slot = preview:CreateTexture(nil, "ARTWORK")
	slot:SetSize(48, 48)
	slot:SetPoint("LEFT", 4, 0)
	if slot.SetAtlas then
		slot:SetAtlas("bags-item-slot64")
	end
	previewIcon = preview:CreateTexture(nil, "OVERLAY")
	previewIcon:SetSize(36, 36)
	previewIcon:SetPoint("CENTER", slot, "CENTER")
	previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	previewOverpower = preview:CreateFontString(nil, "OVERLAY")
	previewOverpower:SetPoint("LEFT", slot, "RIGHT", 12, 10)
	previewDamage = preview:CreateFontString(nil, "OVERLAY")
	previewDamage:SetPoint("TOPLEFT", previewOverpower, "BOTTOMLEFT", 0, -4)

	local fontHeader = SectionHeader(lookPage, "Font", preview, -12)
	local columnWidth = (CONTENT - GAP) / 2
	for i = 1, #ns.FACES do
		local face = ns.FACES[i]
		local button = PanelButton(lookPage, face.label, columnWidth)
		button.faceKey = face.key
		local column = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		button:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", column * (columnWidth + GAP), -8 - row * (ROW + GAP))
		button:SetScript("OnClick", function()
			ChooseFace(face.key)
		end)
		faceButtons[#faceButtons + 1] = button
	end

	local fontRows = math.ceil(#ns.FACES / 2)
	local sizeAnchor = CreateFrame("Frame", nil, lookPage)
	sizeAnchor:SetSize(1, 1)
	sizeAnchor:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -8 - fontRows * (ROW + GAP))

	local sizeHeader = SectionHeader(lookPage, "Size", sizeAnchor, -6)
	local smaller = PanelButton(lookPage, "Smaller", 120)
	smaller:SetPoint("TOPLEFT", sizeHeader, "BOTTOMLEFT", 0, -8)
	smaller:SetScript("OnClick", function()
		ChangeSize(-2)
	end)
	local larger = PanelButton(lookPage, "Larger", 120)
	larger:SetPoint("TOPRIGHT", sizeHeader, "BOTTOMRIGHT", 0, -8)
	larger:SetScript("OnClick", function()
		ChangeSize(2)
	end)
	sizeText = lookPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	sizeText:SetPoint("LEFT", smaller, "RIGHT", 0, 0)
	sizeText:SetPoint("RIGHT", larger, "LEFT", 0, 0)
	sizeText:SetJustifyH("CENTER")

	local outlineHeader = SectionHeader(lookPage, "Outline", smaller, -12)
	local outlineCount = #ns.OUTLINES
	local outlineWidth = (CONTENT - GAP * (outlineCount - 1)) / outlineCount
	for i = 1, outlineCount do
		local outline = ns.OUTLINES[i]
		local button = PanelButton(lookPage, OUTLINE_LABELS[outline] or outline, outlineWidth)
		button.outlineKey = outline
		button:SetPoint("TOPLEFT", outlineHeader, "BOTTOMLEFT", (i - 1) * (outlineWidth + GAP), -8)
		button:SetScript("OnClick", function()
			ChooseOutline(outline)
		end)
		outlineButtons[#outlineButtons + 1] = button
	end

	local alertRoot = CreateFrame("Frame", nil, inset)
	alertRoot:SetPoint("TOPLEFT", nav, "BOTTOMLEFT", 0, -12)
	alertRoot:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -PAD, PAD)
	alertRoot:Hide()

	local intro = alertRoot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	intro:SetPoint("TOPLEFT", alertRoot, "TOPLEFT", 0, 0)
	intro:SetPoint("TOPRIGHT", alertRoot, "TOPRIGHT", 0, 0)
	intro:SetJustifyH("LEFT")
	intro:SetWordWrap(true)
	intro:SetText("Rogue, warrior, priest, and shaman. Learned abilities only. Open a row to read it, and uncheck a row to silence it.")
	intro:SetTextColor(0.95, 0.9, 0.75)

	alertPage = CreateFrame("Frame", nil, alertRoot)
	alertPage:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
	alertPage:SetPoint("TOPRIGHT", intro, "BOTTOMRIGHT", 0, -10)
	alertPage:SetHeight(300)

	emptyText = alertPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", alertPage, "TOPLEFT", 0, -8)
	emptyText:SetPoint("TOPRIGHT", alertPage, "TOPRIGHT", 0, -8)
	emptyText:SetJustifyH("LEFT")
	emptyText:SetWordWrap(true)
	emptyText:SetText("None of these are learned on this character.")
	emptyText:Hide()

	local seenClass = {}
	for i = 1, #ns.ALERTS do
		local alert = ns.ALERTS[i]
		if not seenClass[alert.class] then
			seenClass[alert.class] = true
			local header = CreateFrame("Frame", nil, alertPage)
			header:SetHeight(20)
			header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			header.text:SetPoint("LEFT", 0, 0)
			header.text:SetText(alert.class)
			header.text:SetTextColor(1, 0.82, 0)
			header.line = header:CreateTexture(nil, "ARTWORK")
			header.line:SetTexture("Interface\\Common\\UI-TooltipDivider")
			header.line:SetHeight(8)
			header.line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
			header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -2)
			header:Hide()
			classHeaders[alert.class] = header
		end
		BuildAlertRow(alert)
	end

	local showBody = ShowPage
	ShowPage = function(which)
		showBody(which)
		if which == "alerts" then
			alertRoot:Show()
		else
			alertRoot:Hide()
		end
	end

	ns.RefreshPreview()
	PaintChoices()
	ShowPage("look")
end

function ns.ShowWindow(which)
	ns.InitWindow()
	RestorePosition()
	if which == "alerts" then
		ShowPage("alerts")
	else
		ShowPage("look")
	end
	window:Show()
end
