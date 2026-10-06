local _, ns = ...

local SHEET_W, BASE_H = 384, 512
local LIST_W = 196
local GROW = 1.2
local SCALE_MIN = 0.7
local SCALE_MAX = 1.4
local function U(n)
	return n * GROW
end

local ART = "Interface\\PaperDollInfoFrame\\"
local BUTTONS = "Interface\\Buttons\\"
local SLOT = U(37)
local GAP = U(4)

local window
local suitButton
local nameEdit
local model
local missingPanel
local missingRows
local facing = 0
local picker
local pickerRows
local minimapButton
local docked = false

local function Art(texture, path)
	local ok = texture:SetTexture(path)
	return ok ~= false
end

local function Piece(parent, path, w, h, x, y)
	local tex = parent:CreateTexture(nil, "BACKGROUND", nil, -2)
	Art(tex, path)
	tex:SetSize(U(w), U(h))
	tex:SetPoint("TOPLEFT", parent, "TOPLEFT", U(x), U(y))
	return tex
end

local function LevelLine()
	local level = UnitLevel("player")
	if ns.IsSecret(level) then
		level = ""
	else
		level = tostring(level or "")
	end
	local race = UnitRace("player") or ""
	local class = UnitClass("player") or ""
	return string.format("%s %s %s %s", LEVEL or "Level", level, race, class)
end

function ns.GetScale()
	ns.InitDB()
	local scale = BatsuitMasterDB.scale
	if type(scale) ~= "number" then
		return 1.3
	end
	if scale < SCALE_MIN then
		return SCALE_MIN
	end
	if scale > SCALE_MAX then
		return SCALE_MAX
	end
	return scale
end

function ns.SetScale(scale)
	if type(scale) ~= "number" then
		return
	end
	if scale < SCALE_MIN then
		scale = SCALE_MIN
	end
	if scale > SCALE_MAX then
		scale = SCALE_MAX
	end
	ns.InitDB()
	BatsuitMasterDB.scale = scale
	if window then
		window:SetScale(scale)
	end
end

local function PlayClick()
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

local function SavePosition()
	if not window then
		return
	end
	ns.InitDB()
	local point, _, relative, x, y = window:GetPoint(1)
	if point and relative then
		BatsuitMasterDB.window = { point, relative, x, y }
	end
end

local function RestorePosition()
	local saved = BatsuitMasterDB and BatsuitMasterDB.window
	window:ClearAllPoints()
	if type(saved) == "table" and type(saved[1]) == "string" and type(saved[2]) == "string" then
		window:SetPoint(saved[1], UIParent, saved[2], saved[3] or 0, saved[4] or 0)
	else
		window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

local function CursorItemID()
	if CursorHasItem and not CursorHasItem() then
		return nil
	end
	if not GetCursorInfo then
		return nil
	end
	local ok, kind, a, b, c = pcall(GetCursorInfo)
	if not ok or kind ~= "item" then
		return nil
	end
	local itemID = ns.PlainNumber(a) or ns.PlainNumber(b) or ns.PlainNumber(c)
	if itemID then
		return itemID
	end
	local link = type(a) == "string" and a or type(b) == "string" and b or type(c) == "string" and c
	if type(link) == "string" then
		return ns.PlainNumber(string.match(link, "item:(%d+)"))
	end
	return nil
end

local function HidePicker()
	if picker then
		picker:Hide()
	end
end

local function ApplyIcon(button, itemID, presence)
	if itemID and button.icon then
		local icon = ns.ItemIcon(itemID)
		if icon then
			button.icon:SetTexture(icon)
		end
		button.icon:Show()
		if presence == "bags" or presence == "worn" then
			button.icon:SetVertexColor(1, 1, 1)
		else
			button.icon:SetVertexColor(0.45, 0.45, 0.45)
		end
	elseif button.icon then
		button.icon:Hide()
	end
end

local function ShowPicker(anchor, key, side)
	if not picker then
		return
	end
	local choices = ns.ChoicesForSlot(key)
	local rows = pickerRows
	local shown = 0
	for i = 1, #rows do
		local row = rows[i]
		local choice = choices[i]
		if choice then
			shown = shown + 1
			row.itemID = choice.itemID
			row.slotKey = key
			if choice.icon and not ns.IsSecret(choice.icon) then
				row.icon:SetTexture(choice.icon)
			else
				row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			end
			local label = choice.name
			local copies = choice.bags + choice.bank
			if copies > 1 then
				label = label .. " x" .. copies
			end
			if choice.bags == 0 then
				label = label .. " (Bank)"
			end
			row.text:SetText(label)
			row:Show()
		else
			row:Hide()
		end
	end
	if shown == 0 then
		rows[1].itemID = nil
		rows[1].slotKey = nil
		rows[1].icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		rows[1].text:SetText("Nothing in your bags or bank")
		rows[1]:Show()
		shown = 1
	end
	local height = 12 + shown * 22
	picker:SetHeight(height)
	picker:ClearAllPoints()
	if side == "right" or side == "weapon" then
		picker:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
	else
		picker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
	end
	picker:Show()
end

-- Same gesture as the character sheet: the item is on the cursor, then you
-- click or drop it on a slot. Mouse-up matters because the drag started on the bag.
local missingScroll
local missingContent
local missingEmpty

local function RefreshMissing()
	if not missingPanel or not missingContent then
		return
	end
	local pieces = ns.MissingPieces()
	local count = #pieces
	for i = 1, #missingRows do
		local row = missingRows[i]
		local piece = pieces[i]
		if piece then
			if piece.icon and not ns.IsSecret(piece.icon) then
				row.icon:SetTexture(piece.icon)
			else
				row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			end
			row.name:SetText(piece.name)
			if piece.where == "bank" then
				row.detail:SetText(piece.label .. "  ·  In the bank")
			else
				row.detail:SetText(piece.label .. "  ·  Not in your bags")
			end
			row:Show()
		else
			row:Hide()
		end
	end
	local height = count * 36
	if height < 1 then
		height = 1
	end
	missingContent:SetHeight(height)
	if missingEmpty then
		if count == 0 then
			missingEmpty:Show()
		else
			missingEmpty:Hide()
		end
	end
	if missingScroll and missingScroll.ScrollBar then
		local view = missingScroll:GetHeight() or 0
		missingScroll.ScrollBar:SetShown(height > view + 1)
		if height <= view + 1 then
			missingScroll:SetVerticalScroll(0)
		end
	end
	missingPanel:Show()
end

local function BuildMissingPanel(parent)
	missingPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	missingPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", U(SHEET_W) + U(4), -U(12))
	missingPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -U(8), U(12))
	missingPanel:SetFrameLevel(parent:GetFrameLevel() + 8)
	missingPanel:SetBackdrop({
		bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 256,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	missingPanel:SetBackdropColor(1, 1, 1, 1)
	missingPanel:SetBackdropBorderColor(0.7, 0.58, 0.3, 0.9)
	missingPanel:EnableMouse(true)

	local title = missingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetPoint("TOPRIGHT", -12, -10)
	title:SetJustifyH("LEFT")
	title:SetText("Not in your bags")

	missingEmpty = missingPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	missingEmpty:SetPoint("TOPLEFT", 14, -36)
	missingEmpty:SetPoint("RIGHT", missingPanel, "RIGHT", -16, 0)
	missingEmpty:SetJustifyH("LEFT")
	missingEmpty:SetText("Every piece is in your bags or equipped.")
	missingEmpty:Hide()

	missingScroll = CreateFrame("ScrollFrame", "BatsuitMasterMissingScroll", missingPanel, "UIPanelScrollFrameTemplate")
	missingScroll:SetPoint("TOPLEFT", 8, -30)
	missingScroll:SetPoint("BOTTOMRIGHT", -26, 10)
	missingScroll:SetFrameLevel(missingPanel:GetFrameLevel() + 2)

	missingContent = CreateFrame("Frame", nil, missingScroll)
	missingContent:SetSize(140, 1)
	missingScroll:SetScrollChild(missingContent)
	missingScroll:SetScript("OnSizeChanged", function(self)
		local width = self:GetWidth()
		if width and width > 20 then
			missingContent:SetWidth(width)
		end
	end)

	missingRows = {}
	for i = 1, #ns.SLOTS do
		local row = CreateFrame("Frame", nil, missingContent)
		row:SetHeight(32)
		row:SetPoint("TOPLEFT", missingContent, "TOPLEFT", 0, -(i - 1) * 36)
		row:SetPoint("TOPRIGHT", missingContent, "TOPRIGHT", 0, -(i - 1) * 36)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(28, 28)
		row.icon:SetPoint("LEFT", 0, 0)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
		row.name:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 1)
		row.detail:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.detail:SetJustifyH("LEFT")
		row.detail:SetTextColor(1, 0.35, 0.35)
		row:Hide()
		missingRows[i] = row
	end
end

local function TakeCursor(key)
	if CursorHasItem and not CursorHasItem() then
		return false
	end
	local itemID = CursorItemID()
	if not itemID then
		if CursorHasItem and CursorHasItem() then
			ns.Print("Could not read that item.")
			return true
		end
		return false
	end
	local placed = ns.SetSlot(key, itemID, true)
	if placed and ClearCursor then
		pcall(ClearCursor)
	end
	return true
end

local function RefreshModel()
	if not model then
		return
	end
	pcall(model.SetUnit, model, "player")
	if model.Dress then
		pcall(model.Dress, model)
	end
	if model.Undress then
		pcall(model.Undress, model)
	end
	local suit = ns.CurrentSuit()
	if model.TryOn then
		for i = 1, #ns.SLOTS do
			local itemID = suit.slots[ns.SLOTS[i].key]
			if itemID then
				pcall(model.TryOn, model, ns.LinkFor(itemID))
			end
		end
	end
	if model.SetRotation then
		pcall(model.SetRotation, model, facing)
	end
end

local function RefreshSuitButton()
	if not suitButton then
		return
	end
	local ready = ns.CanSuitUp()
	if ready then
		suitButton:Enable()
	else
		suitButton:Disable()
	end
	local font = suitButton:GetFontString()
	if font then
		if ready then
			font:SetTextColor(1, 0.125, 0.125)
		else
			font:SetTextColor(0.5, 0.5, 0.5)
		end
	end
end

function ns.RefreshWindow()
	if not window then
		return
	end
	if ns.RefreshDropdown then
		ns.RefreshDropdown()
	end
	if nameEdit and not nameEdit:HasFocus() then
		nameEdit:SetText(ns.SuitName())
	end
	if window.levelText then
		window.levelText:SetText(LevelLine())
	end
	if window.nameText then
		local name = UnitName("player")
		if ns.PlainString(name) then
			window.nameText:SetText(name)
		end
	end
	if window.portrait and SetPortraitTexture then
		pcall(SetPortraitTexture, window.portrait, "player")
	end
	local suit = ns.CurrentSuit()
	for i = 1, #ns.SLOTS do
		local info = ns.SLOTS[i]
		local button = window.slots[info.key]
		if button then
			local itemID = suit.slots[info.key]
			ApplyIcon(button, itemID, itemID and ns.SlotPresence(info.key))
		end
	end
	RefreshSuitButton()
	RefreshModel()
	RefreshMissing()
	HidePicker()
end

local function SlotButton(parent, info, x, y, anchor, relPoint)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(SLOT, SLOT)
	button:SetPoint(anchor or "TOPLEFT", parent, relPoint or "TOPLEFT", x, y)
	local empty = button:CreateTexture(nil, "BACKGROUND")
	empty:SetAllPoints()
	local texture = ns.EmptyTexture(info.key)
	if texture then
		empty:SetTexture(texture)
	else
		empty:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	end
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:Hide()
	button.icon = icon
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
	end
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	local function Place()
		if TakeCursor(info.key) then
			button.placed = true
			HidePicker()
		end
	end
	button:SetScript("OnReceiveDrag", Place)
	button:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "LeftButton" then
			Place()
		end
	end)
	button:SetScript("OnClick", function(_, mouse)
		if button.placed then
			button.placed = nil
			HidePicker()
			return
		end
		HidePicker()
		if mouse == "RightButton" then
			if CursorHasItem and CursorHasItem() then
				return
			end
			ns.ClearSlot(info.key)
			return
		end
		if TakeCursor(info.key) then
			return
		end
		ShowPicker(button, info.key, info.side)
	end)
	button:SetScript("OnEnter", function(self)
		local itemID = ns.CurrentSuit().slots[info.key]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if itemID then
			GameTooltip:SetItemByID(itemID)
			local presence = ns.SlotPresence(info.key)
			if presence == "worn" then
				GameTooltip:AddLine("Equipped", 0.4, 1, 0.4)
			elseif presence == "bank" then
				GameTooltip:AddLine("In the bank", 1, 0.2, 0.2)
			elseif presence == "missing" then
				GameTooltip:AddLine("Not in your bags", 1, 0.2, 0.2)
			end
			GameTooltip:AddLine("Right-click to clear", 0.8, 0.8, 0.8)
		else
			GameTooltip:SetText("Empty", 1, 1, 1)
			GameTooltip:AddLine("Drop an item here, or click to choose one.", 1, 0.82, 0)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function Column(parent, side)
	local slots = {}
	local prev
	for i = 1, #ns.SLOTS do
		local info = ns.SLOTS[i]
		if info.side == side then
			local button
			if prev then
				button = SlotButton(parent, info, 0, -GAP, "TOPLEFT", "BOTTOMLEFT")
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -GAP)
			else
				local x = side == "left" and U(21) or U(306)
				button = SlotButton(parent, info, x, -U(74))
			end
			slots[info.key] = button
			prev = button
		end
	end
	return slots
end

local function WeaponRow(parent)
	local slots = {}
	local prev
	for i = 1, #ns.SLOTS do
		local info = ns.SLOTS[i]
		if info.side == "weapon" then
			local button = SlotButton(parent, info, 0, 0)
			button:ClearAllPoints()
			if prev then
				button:SetPoint("TOPLEFT", prev, "TOPRIGHT", U(5), 0)
			else
				button:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", U(122), U(127))
			end
			slots[info.key] = button
			prev = button
		end
	end
	return slots
end

local function TurnButton(parent, pathKey, direction, anchor, relPoint, dx)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(U(32), U(32))
	button:SetPoint("TOPLEFT", anchor, relPoint, dx or 0, 0)
	button:SetNormalTexture(BUTTONS .. pathKey .. "-Button-Up")
	button:SetPushedTexture(BUTTONS .. pathKey .. "-Button-Down")
	button:SetHighlightTexture(BUTTONS .. "ButtonHilight-Round")
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
	end
	local spinner = CreateFrame("Frame", nil, button)
	spinner:Hide()
	spinner.turn = direction == "left" and -1 or 1
	spinner:SetScript("OnUpdate", function(self, elapsed)
		facing = facing + self.turn * elapsed * 2
		if model and model.SetRotation then
			model:SetRotation(facing)
		end
	end)
	button:SetScript("OnMouseDown", function()
		spinner:Show()
	end)
	button:SetScript("OnMouseUp", function()
		spinner:Hide()
	end)
	button:SetScript("OnLeave", function()
		spinner:Hide()
	end)
	return button
end

local function BuildDropdown(parent)
	if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_SetWidth and UIDropDownMenu_SetText and UIDropDownMenu_AddButton then
		local ok, dropdown = pcall(CreateFrame, "Frame", "BatsuitMasterSuitDropDown", parent, "UIDropDownMenuTemplate")
		if ok and dropdown then
			local ready = pcall(function()
				UIDropDownMenu_SetWidth(dropdown, 120)
				UIDropDownMenu_Initialize(dropdown, function()
					local here = ns.ActiveIndex()
					for i = 1, ns.SUIT_COUNT do
						local info = UIDropDownMenu_CreateInfo()
						info.text = ns.SuitName(i)
						info.checked = i == here
						info.func = function()
							ns.SetActive(i)
						end
						UIDropDownMenu_AddButton(info)
					end
				end)
				UIDropDownMenu_SetText(dropdown, ns.SuitName())
			end)
			if ready then
				ns.RefreshDropdown = function()
					UIDropDownMenu_SetText(dropdown, ns.SuitName())
				end
				return dropdown
			end
			dropdown:Hide()
		end
	end

	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(U(140), U(22))
	button:SetText(ns.SuitName())
	local menu = CreateFrame("Frame", nil, button, "TooltipBorderedFrameTemplate")
	menu:SetSize(U(140), U(8 + ns.SUIT_COUNT * 22))
	menu:SetPoint("TOP", button, "BOTTOM", 0, -2)
	menu:SetFrameStrata("DIALOG")
	menu:Hide()
	for i = 1, ns.SUIT_COUNT do
		local row = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
		row:SetSize(U(124), U(20))
		row:SetPoint("TOP", menu, "TOP", 0, -U(6 + (i - 1) * 22))
		row:SetText(ns.SuitName(i))
		row:SetScript("OnClick", function()
			PlayClick()
			menu:Hide()
			ns.SetActive(i)
		end)
		menu["row" .. i] = row
	end
	button:SetScript("OnClick", function()
		PlayClick()
		if menu:IsShown() then
			menu:Hide()
		else
			for i = 1, ns.SUIT_COUNT do
				menu["row" .. i]:SetText(ns.SuitName(i))
			end
			menu:Show()
		end
	end)
	ns.RefreshDropdown = function()
		button:SetText(ns.SuitName())
		if menu:IsShown() then
			for i = 1, ns.SUIT_COUNT do
				menu["row" .. i]:SetText(ns.SuitName(i))
			end
		end
	end
	return button
end

local function BuildPicker()
	picker = CreateFrame("Frame", "BatsuitMasterPicker", UIParent, "TooltipBorderedFrameTemplate")
	picker:SetSize(240, 40)
	picker:SetFrameStrata("DIALOG")
	picker:Hide()
	pickerRows = {}
	for i = 1, 24 do
		local row = CreateFrame("Button", nil, picker)
		row:SetHeight(20)
		row:SetPoint("TOPLEFT", picker, "TOPLEFT", 8, -6 - (i - 1) * 22)
		row:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -8, -6 - (i - 1) * 22)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(16, 16)
		row.icon:SetPoint("LEFT", 0, 0)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row:SetScript("OnClick", function(self)
			if self.itemID and self.slotKey then
				ns.SetSlot(self.slotKey, self.itemID)
			end
			HidePicker()
		end)
		row:Hide()
		pickerRows[i] = row
	end
end

local function AnchorLooseButton()
	if not minimapButton or docked or not Minimap then
		return
	end
	minimapButton:SetParent(UIParent)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "LEFT", 0, -30)
	minimapButton:Show()
end

function ns.DockMinimapButton()
	if not minimapButton then
		return
	end
	if type(TobarisuMap) == "table" and type(TobarisuMap.RegisterWidget) == "function" then
		TobarisuMap.RegisterWidget("BatsuitMaster", {
			frame = minimapButton,
			edge = "W",
			size = 26,
		})
		docked = true
		minimapButton:Show()
		return
	end
	docked = false
	AnchorLooseButton()
end

local function InitMinimapButton()
	if minimapButton then
		ns.DockMinimapButton()
		return
	end
	minimapButton = CreateFrame("Button", "BatsuitMasterMinimapButton", UIParent)
	minimapButton:SetSize(26, 26)
	minimapButton:RegisterForClicks("LeftButtonUp")
	minimapButton:SetFrameStrata("MEDIUM")

	local disc = minimapButton:CreateTexture(nil, "BACKGROUND")
	disc:SetAllPoints()
	disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	disc:SetVertexColor(0.08, 0.06, 0.04, 1)

	local ring = minimapButton:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(42, 42)
	ring:SetPoint("CENTER", 8, -8)

	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local highlight = minimapButton:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
		highlight:ClearAllPoints()
		highlight:SetPoint("CENTER")
		highlight:SetSize(22, 22)
	end

	local label = CreateFrame("Frame", nil, minimapButton)
	label:SetAllPoints()
	label:SetFrameLevel(minimapButton:GetFrameLevel() + 2)
	local text = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if not text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") then
		text:SetFontObject("GameFontNormalSmall")
	end
	text:SetText("BSM")
	text:SetTextColor(1, 0.82, 0)
	text:SetPoint("CENTER", 0, 0)

	minimapButton:SetScript("OnClick", function()
		ns.ToggleWindow()
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("BatsuitMaster")
		GameTooltip:AddLine("Open the suit sheet", 1, 1, 1)
		GameTooltip:AddLine("Drag around the map", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	ns.DockMinimapButton()
end

local function BuildWindow()
	if window then
		return
	end
	window = CreateFrame("Frame", "BatsuitMasterFrame", UIParent)
	table.insert(UISpecialFrames, "BatsuitMasterFrame")
	window:SetSize(U(SHEET_W + LIST_W), U(BASE_H))
	window:SetFrameStrata("MEDIUM")
	window:SetToplevel(false)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		HidePicker()
		if self.settingsMenu then
			self.settingsMenu:Hide()
		end
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	window:SetScript("OnMouseDown", function(self)
		HidePicker()
		if self.settingsMenu then
			self.settingsMenu:Hide()
		end
	end)
	window:SetScript("OnHide", HidePicker)
	window:Hide()
	RestorePosition()
	window:SetScale(ns.GetScale())

	Piece(window, ART .. "UI-Character-General-TopLeft", 256, 256, 0, 0)
	Piece(window, ART .. "UI-Character-General-TopRight", 128, 256, 256, 0)
	Piece(window, ART .. "UI-Character-General-BottomLeft", 256, 256, 0, -256)
	Piece(window, ART .. "UI-Character-General-BottomRight", 128, 256, 256, -256)
	Piece(window, ART .. "UI-Character-CharacterTab-L1", 256, 256, 0, 0)
	Piece(window, ART .. "UI-Character-CharacterTab-R1", 128, 256, 256, 0)
	Piece(window, ART .. "UI-Character-CharacterTab-BottomLeft", 256, 256, 0, -256)
	Piece(window, ART .. "UI-Character-CharacterTab-BottomRight", 128, 256, 256, -256)

	local ring = CreateFrame("Frame", nil, window)
	ring:SetSize(U(80), U(73))
	ring:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
	ring:SetFrameLevel(window:GetFrameLevel() + 4)
	local ringTex = ring:CreateTexture(nil, "ARTWORK")
	Art(ringTex, ART .. "UI-Character-General-TopLeft")
	ringTex:SetAllPoints(ring)
	ringTex:SetTexCoord(0, 80 / 256, 0, 73 / 256)

	local portrait = window:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(U(60), U(60))
	portrait:SetPoint("TOPLEFT", window, "TOPLEFT", U(8), -U(7))
	window.portrait = portrait

	local nameText = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetJustifyH("CENTER")
	-- Same spot as OldManQuester: center of the 384-wide sheet, nudged past the portrait.
	nameText:SetPoint("CENTER", window, "TOPLEFT", U(SHEET_W) / 2 + U(6), -U(24))
	window.nameText = nameText

	local levelText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	levelText:SetJustifyH("CENTER")
	levelText:SetPoint("TOP", nameText, "BOTTOM", 0, -U(6))
	window.levelText = levelText

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("CENTER", window, "TOPLEFT", U(SHEET_W) - U(44), -U(25))
	close:SetScript("OnClick", function()
		window:Hide()
	end)

	local gearButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	gearButton:SetSize(32, 22)
	gearButton:SetScale(0.8)
	gearButton:SetText("")
	gearButton:SetPoint("RIGHT", close, "LEFT", -8, 0)
	gearButton:SetFrameLevel(window:GetFrameLevel() + 6)
	local gearIcon = gearButton:CreateTexture(nil, "OVERLAY")
	gearIcon:SetSize(16, 16)
	gearIcon:SetPoint("CENTER", 0, 1)
	gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	gearButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Settings")
		GameTooltip:Show()
	end)
	gearButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	gearButton:SetScript("OnClick", function()
		PlayClick()
		local menu = window.settingsMenu
		if menu and menu:IsShown() then
			menu:Hide()
			return
		end
		if menu then
			menu:Show()
		end
	end)

	local settingsMenu = CreateFrame("Frame", nil, window, "BackdropTemplate")
	settingsMenu:SetSize(176, 72)
	settingsMenu:SetFrameLevel(window:GetFrameLevel() + 30)
	settingsMenu:SetPoint("TOPRIGHT", gearButton, "BOTTOMRIGHT", 8, -6)
	settingsMenu:SetBackdrop({
		bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 256,
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	settingsMenu:SetBackdropColor(1, 1, 1, 1)
	settingsMenu:SetBackdropBorderColor(0.7, 0.58, 0.3, 0.9)
	settingsMenu:EnableMouse(true)
	settingsMenu:Hide()
	window.settingsMenu = settingsMenu

	local scaleSlider = CreateFrame("Slider", nil, settingsMenu, "UISliderTemplateWithLabels")
	scaleSlider:SetSize(144, 17)
	scaleSlider:SetPoint("CENTER", 0, -6)
	scaleSlider:SetMinMaxValues(SCALE_MIN, SCALE_MAX)
	scaleSlider:SetValueStep(0.05)
	if scaleSlider.SetObeyStepOnDrag then
		scaleSlider:SetObeyStepOnDrag(true)
	end
	scaleSlider.Text:SetText("Scale")
	scaleSlider.Low:SetText("70%")
	scaleSlider.High:SetText("140%")
	local function ShowScale(value)
		local percent = math.floor((value * 100) + 0.5)
		scaleSlider.Text:SetText("Scale " .. percent .. "%")
	end
	scaleSlider:SetScript("OnValueChanged", function(self, value)
		ShowScale(value)
		if self.quiet then
			return
		end
		self.pending = value
	end)
	scaleSlider:SetScript("OnMouseUp", function(self)
		if self.pending then
			ns.SetScale(self.pending)
			self.pending = nil
		end
	end)
	settingsMenu:SetScript("OnShow", function()
		scaleSlider.quiet = true
		scaleSlider:SetValue(ns.GetScale())
		scaleSlider.quiet = false
		ShowScale(ns.GetScale())
	end)

	local dropdown = BuildDropdown(window)
	dropdown:SetPoint("TOPLEFT", window, "TOPLEFT", U(86), -U(46))

	nameEdit = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
	nameEdit:SetSize(U(110), U(20))
	nameEdit:SetPoint("TOPLEFT", window, "TOPLEFT", U(220), -U(48))
	nameEdit:SetAutoFocus(false)
	nameEdit:SetMaxLetters(24)
	nameEdit:SetFontObject("GameFontHighlightSmall")
	nameEdit:SetScript("OnEnterPressed", function(self)
		self.saving = true
		ns.RenameSuit(self:GetText())
		self:SetText(ns.SuitName())
		self:ClearFocus()
		self.saving = nil
	end)
	nameEdit:SetScript("OnEscapePressed", function(self)
		self:SetText(ns.SuitName())
		self:ClearFocus()
	end)
	nameEdit:SetScript("OnEditFocusLost", function(self)
		if not self.saving then
			self:SetText(ns.SuitName())
		end
	end)

	local ok, created = pcall(CreateFrame, "DressUpModel", nil, window)
	if ok and created then
		model = created
	else
		model = CreateFrame("PlayerModel", nil, window)
	end
	model:SetPoint("TOPLEFT", window, "TOPLEFT", U(65), -U(100))
	model:SetSize(U(233), U(200))
	model:SetFrameLevel(window:GetFrameLevel() + 2)
	model:EnableMouse(true)
	model:SetScript("OnMouseDown", HidePicker)
	local leftTurn = TurnButton(window, "UI-RotationLeft", "left", model, "TOPLEFT", 0)
	local rightTurn = TurnButton(window, "UI-RotationRight", "right", model, "TOPLEFT", U(32))
	leftTurn:SetFrameLevel(model:GetFrameLevel() + 5)
	rightTurn:SetFrameLevel(model:GetFrameLevel() + 5)

	window.slots = {}
	local left = Column(window, "left")
	local right = Column(window, "right")
	local weapons = WeaponRow(window)
	for key, button in pairs(left) do
		window.slots[key] = button
		button:SetFrameLevel(window:GetFrameLevel() + 3)
	end
	for key, button in pairs(right) do
		window.slots[key] = button
		button:SetFrameLevel(window:GetFrameLevel() + 3)
	end
	for key, button in pairs(weapons) do
		window.slots[key] = button
		button:SetFrameLevel(window:GetFrameLevel() + 3)
	end

	suitButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	suitButton:SetSize(U(96), U(22))
	-- Above the weapon slots, in the open parchment under the model.
	suitButton:SetPoint("BOTTOM", window, "BOTTOMLEFT", U(SHEET_W) / 2, U(127) + U(18))
	suitButton:SetFrameLevel(window:GetFrameLevel() + 6)
	suitButton:SetText("Suit Up")
	suitButton:SetMotionScriptsWhileDisabled(true)
	suitButton:SetScript("OnClick", function()
		if not ns.CanSuitUp() then
			return
		end
		PlayClick()
		ns.SuitUp()
	end)
	suitButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Suit Up", 1, 0.125, 0.125)
		if ns.CanSuitUp() then
			GameTooltip:AddLine("Wear this loadout and bag everything else.", 1, 1, 1)
		else
			GameTooltip:AddLine("Every piece has to be in your bags.", 1, 0.82, 0)
		end
		GameTooltip:Show()
	end)
	suitButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	BuildPicker()
	BuildMissingPanel(window)
	ns.model = model
end

function ns.IsWindowShown()
	return window and window:IsShown()
end

local function BagsAreOpen()
	local bags = _G.BagMasterFrame
	if bags and bags:IsShown() then
		return true
	end
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
		return true
	end
	return false
end

local function KeepBehindBags()
	if not window then
		return
	end
	if BagsAreOpen() then
		window:SetFrameStrata("LOW")
	else
		window:SetFrameStrata("MEDIUM")
	end
end

local function WatchBags(frame)
	if not frame or frame.bsmBagWatch then
		return
	end
	frame.bsmBagWatch = true
	frame:HookScript("OnShow", KeepBehindBags)
	frame:HookScript("OnHide", KeepBehindBags)
end

function ns.ShowWindow()
	if not window then
		BuildWindow()
	end
	WatchBags(_G.BagMasterFrame)
	WatchBags(ContainerFrameCombinedBags)
	KeepBehindBags()
	window:Show()
	ns.RefreshWindow()
end

function ns.HideWindow()
	if window then
		window:Hide()
	end
end

function ns.ToggleWindow()
	if ns.IsWindowShown() then
		ns.HideWindow()
	else
		ns.ShowWindow()
	end
end

function ns.InitWindow()
	BuildWindow()
	InitMinimapButton()
end
