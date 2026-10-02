local _, ns = ...

local window
local searchBox
local moneyText
local moneyFrame
local tokenFrame
local hookedToggles = false
local cacheHooked = false
local originals = {}

local TOP_BAR = 32
local BOTTOM_BAR = 36
local PAD = 10
local WELL_PAD = 5
local CONTENT_INSET = 16
local CONTENT_V_INSET = 8
local SCALE_MIN = 0.7
local SCALE_MAX = 1.4
local FOOTER_BOTTOM = 8
local FOOTER_GAP = 4
local BOX_HEIGHT = 17
local TOKEN_GAP = 3

function ns.GetScale()
	local scale = BagMasterDB and BagMasterDB.scale
	if type(scale) ~= "number" then
		return 1
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
	BagMasterDB.scale = scale
	if window then
		window:SetScale(scale)
	end
end

function ns.GetWindow()
	return window
end

function ns.GetContent()
	return window and window.content
end

function ns.IsWindowShown()
	return window and window:IsShown()
end

local function HideBlizzardBags()
	if ContainerFrameCombinedBags then
		ContainerFrameCombinedBags:Hide()
	end
	local count = NUM_CONTAINER_FRAMES or 13
	for i = 1, count do
		local frame = _G["ContainerFrame" .. i]
		if frame then
			frame:Hide()
		end
	end
end

local function UpdateMoney()
	if moneyFrame and MoneyFrame_UpdateMoney then
		pcall(MoneyFrame_UpdateMoney, moneyFrame)
		return
	end
	if not moneyText then
		return
	end
	local amount = GetMoney()
	if amount == nil then
		amount = 0
	end
	if GetCoinTextureString then
		local ok, text = pcall(GetCoinTextureString, amount)
		if ok and text then
			moneyText:SetText(text)
			return
		end
	end
	local ok, text = pcall(tostring, amount)
	if ok and text then
		moneyText:SetText(text)
	end
end

function ns.UpdateMoney()
	UpdateMoney()
end

local function EnsureTokenUI()
	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_TokenUI")
	elseif LoadAddOn then
		pcall(LoadAddOn, "Blizzard_TokenUI")
	end
end

local function EnsureTokenFrame()
	if tokenFrame or not window then
		return tokenFrame
	end
	EnsureTokenUI()
	local ok, frame = pcall(CreateFrame, "Frame", "BagMasterTokenFrame", window, "BackpackTokenFrameTemplate")
	if not ok or not frame then
		return nil
	end
	tokenFrame = frame
	tokenFrame:SetFrameLevel((window:GetFrameLevel() or 1) + 40)
	return tokenFrame
end

local function BoxWidth(width)
	local inner = width - 16
	if inner < 50 then
		inner = 50
	end
	return inner
end

local function RefreshTokenFrame(width)
	local frame = EnsureTokenFrame()
	if not frame then
		return 0
	end
	frame:ClearAllPoints()
	frame:SetSize(BoxWidth(width), BOX_HEIGHT)
	frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, FOOTER_BOTTOM)
	if frame.SetIsCombinedInventory then
		frame:SetIsCombinedInventory(true)
	end
	local updated = pcall(function()
		frame:Update()
	end)
	local shown = false
	if updated and frame.ShouldShow then
		local ok, result = pcall(frame.ShouldShow, frame)
		shown = ok and result
	end
	if not shown then
		frame:Hide()
		return 0
	end
	frame:Show()
	if frame.UpdateTokenAnchoring then
		pcall(frame.UpdateTokenAnchoring, frame)
	end
	return BOX_HEIGHT
end

function ns.LayoutFooter(width)
	if not window then
		return BOTTOM_BAR
	end
	local tokenHeight = RefreshTokenFrame(width)
	local moneyY = FOOTER_BOTTOM
	if tokenHeight > 0 then
		moneyY = FOOTER_BOTTOM + tokenHeight + TOKEN_GAP
	end
	if moneyFrame then
		moneyFrame:ClearAllPoints()
		moneyFrame:SetHeight(BOX_HEIGHT)
		moneyFrame:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 8, moneyY)
		moneyFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, moneyY)
		moneyFrame:SetFrameLevel((window:GetFrameLevel() or 1) + 40)
		moneyFrame:Show()
	elseif moneyText then
		moneyText:ClearAllPoints()
		moneyText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, moneyY)
	end
	UpdateMoney()
	local footer = moneyY + BOX_HEIGHT + FOOTER_GAP
	window.BOTTOM_BAR = footer
	if window.content then
		window.content:ClearAllPoints()
		window.content:SetPoint("TOPLEFT", CONTENT_INSET, -(TOP_BAR + CONTENT_V_INSET))
		window.content:SetPoint("BOTTOMRIGHT", -CONTENT_INSET, footer + CONTENT_V_INSET)
	end
	if window.well then
		window.well:ClearAllPoints()
		window.well:SetPoint("TOPLEFT", WELL_PAD, -TOP_BAR)
		window.well:SetPoint("BOTTOMRIGHT", -WELL_PAD, footer)
	end
	return footer
end

function ns.ReflowFooter()
	if not window or not window:IsShown() or not window.itemHeight then
		UpdateMoney()
		return
	end
	local width = window:GetWidth()
	local footer = ns.LayoutFooter(width)
	local top = window.TOP_BAR or TOP_BAR
	local vInset = window.CONTENT_V_INSET or 0
	ns.SetWindowSize(width, top + vInset + window.itemHeight + vInset + footer)
end

local function SavePosition()
	if not window then
		return
	end
	local point, _, _, x, y = window:GetPoint(1)
	BagMasterDB.point = point
	BagMasterDB.x = x
	BagMasterDB.y = y
end

local function RestorePosition()
	if not window then
		return
	end
	window:ClearAllPoints()
	if BagMasterDB.point then
		window:SetPoint(BagMasterDB.point, UIParent, BagMasterDB.point, BagMasterDB.x or 0, BagMasterDB.y or 0)
	else
		window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
	end
end

function ns.ShowWindow()
	if not ns.IsEnabled() then
		return
	end
	if not window then
		ns.InitWindow()
	end
	if not window then
		return
	end
	HideBlizzardBags()
	window:Show()
	ns.RefreshBags()
	UpdateMoney()
end

function ns.HideWindow()
	if window then
		window:Hide()
	end
	HideBlizzardBags()
end

local function WrapToggle(name, handler)
	if originals[name] or type(_G[name]) ~= "function" then
		return
	end
	originals[name] = _G[name]
	_G[name] = function(...)
		if ns.IsEnabled() then
			return handler(originals[name], ...)
		end
		return originals[name](...)
	end
end

local function HookCache()
	if cacheHooked then
		return
	end
	if type(BackendMaster) ~= "table" or type(BackendMaster.RegisterCallback) ~= "function" then
		return
	end
	cacheHooked = true
	BackendMaster.RegisterCallback("BagCacheUpdate", function()
		if not ns.IsEnabled() or not ns.IsWindowShown() then
			return
		end
		ns.RefreshBags()
	end)
end

local function HookBagToggles()
	if hookedToggles then
		return
	end
	hookedToggles = true
	if ContainerFrameCombinedBags then
		ContainerFrameCombinedBags:HookScript("OnShow", function(self)
			if ns.IsEnabled() then
				self:Hide()
			end
		end)
	end
	local count = NUM_CONTAINER_FRAMES or 13
	for i = 1, count do
		local frame = _G["ContainerFrame" .. i]
		if frame then
			frame:HookScript("OnShow", function(self)
				if ns.IsEnabled() then
					self:Hide()
				end
			end)
		end
	end
	WrapToggle("ToggleBackpack", function()
		if ns.IsWindowShown() then
			ns.HideWindow()
		else
			ns.ShowWindow()
		end
	end)
	WrapToggle("ToggleAllBags", function()
		if ns.IsWindowShown() then
			ns.HideWindow()
		else
			ns.ShowWindow()
		end
	end)
	WrapToggle("OpenAllBags", function()
		ns.ShowWindow()
	end)
	WrapToggle("CloseAllBags", function()
		ns.HideWindow()
	end)
	WrapToggle("OpenBackpack", function()
		ns.ShowWindow()
	end)
	WrapToggle("CloseBackpack", function()
		ns.HideWindow()
	end)
end

local function OnSearchChanged(self)
	local text = self:GetText() or ""
	if C_Container and C_Container.SetItemSearch then
		C_Container.SetItemSearch(text)
	end
	if ns.ApplySearchKeywords then
		ns.ApplySearchKeywords()
	end
end

function ns.GetSearchQuery()
	if not searchBox or not searchBox.GetText then
		return ""
	end
	local text = searchBox:GetText() or ""
	return string.lower(string.match(text, "^%s*(.-)%s*$") or "")
end

function ns.FocusSearch()
	if not ns.IsWindowShown() then
		ns.ShowWindow()
	end
	local function focus()
		if searchBox and searchBox.SetFocus then
			searchBox:SetFocus()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, focus)
	else
		focus()
	end
end

function ns.SetWindowSize(width, height)
	if not window then
		return
	end
	local point, relativeTo, relativePoint, x, y = window:GetPoint(1)
	local oldTop = window:GetTop()
	local holdTop = point and not string.find(point, "TOP", 1, true)
	window:SetSize(width, height)
	if not holdTop or not oldTop or y == nil then
		return
	end
	local newTop = window:GetTop()
	if not newTop then
		return
	end
	local delta = newTop - oldTop
	if delta == 0 then
		return
	end
	local parent = relativeTo or UIParent
	local parentScale = 1
	if parent.GetEffectiveScale then
		parentScale = parent:GetEffectiveScale() or 1
	end
	local scale = window:GetEffectiveScale() or 1
	if parentScale > 0 then
		delta = delta * scale / parentScale
	end
	window:SetPoint(point, parent, relativePoint or point, x or 0, y - delta)
end

function ns.InitWindow()
	if window then
		HookBagToggles()
		HookCache()
		return true
	end

	window = CreateFrame("Frame", "BagMasterFrame", UIParent, "BackdropTemplate")
	window:SetFrameStrata("MEDIUM")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetSize(420, 500)
	window:SetScale(ns.GetScale())
	window:Hide()
	window:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	window:SetBackdropColor(0.36, 0.26, 0.15, 0.98)
	window:SetBackdropBorderColor(0.62, 0.45, 0.22, 1)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	window:SetScript("OnHide", function()
		SavePosition()
		if window.settingsMenu then
			window.settingsMenu:Hide()
		end
	end)
	tinsert(UISpecialFrames, "BagMasterFrame")

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function()
		ns.HideWindow()
	end)

	local layoutButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	layoutButton:SetSize(64, 22)
	layoutButton:SetScale(0.8)
	layoutButton:SetScript("OnClick", function()
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		if ns.GetLayout() == "bags" then
			ns.SetLayout("category")
		else
			ns.SetLayout("bags")
		end
	end)
	function ns.UpdateLayoutButton()
		if ns.GetLayout() == "bags" then
			layoutButton:SetText("Bags")
		else
			layoutButton:SetText("Type")
		end
	end
	ns.UpdateLayoutButton()

	local gearButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	gearButton:SetSize(32, 22)
	gearButton:SetScale(0.8)
	gearButton:SetText("")
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
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		local menu = window.settingsMenu
		if menu and menu:IsShown() then
			menu:Hide()
			return
		end
		if menu then
			menu:Show()
		end
	end)

	searchBox = CreateFrame("EditBox", "BagMasterSearchBox", window, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	gearButton:SetPoint("TOPRIGHT", close, "TOPLEFT", -12, -9)
	layoutButton:SetPoint("TOPRIGHT", gearButton, "TOPLEFT", -8, 0)
	searchBox:SetPoint("TOPLEFT", PAD, -6)
	searchBox:SetPoint("TOPRIGHT", layoutButton, "TOPLEFT", -8, 0)

	local settingsMenu = CreateFrame("Frame", nil, window, "BackdropTemplate")
	settingsMenu:SetSize(176, 72)
	settingsMenu:SetFrameLevel((window:GetFrameLevel() or 1) + 30)
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
	searchBox:SetAutoFocus(false)
	searchBox:SetMaxLetters(40)
	searchBox:SetScript("OnTextChanged", function(self)
		if SearchBoxTemplate_OnTextChanged then
			SearchBoxTemplate_OnTextChanged(self)
		end
		OnSearchChanged(self)
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self:SetText("")
		OnSearchChanged(self)
	end)
	window.searchBox = searchBox

	local createdMoney = false
	if CreateFrame then
		local ok, frame = pcall(CreateFrame, "Frame", "BagMasterMoneyFrame", window, "ContainerMoneyFrameTemplate")
		if ok and frame then
			moneyFrame = frame
			createdMoney = true
		end
	end
	if createdMoney then
		moneyFrame:ClearAllPoints()
		moneyFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, FOOTER_BOTTOM)
		moneyFrame:SetFrameLevel((window:GetFrameLevel() or 1) + 40)
		moneyFrame:Show()
	else
		moneyText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		moneyText:SetPoint("BOTTOMRIGHT", -16, FOOTER_BOTTOM)
		moneyText:SetJustifyH("RIGHT")
	end
	window.moneyText = moneyText

	local well = CreateFrame("Frame", nil, window, "BackdropTemplate")
	well:SetFrameLevel((window:GetFrameLevel() or 1) + 1)
	well:SetBackdrop({
		bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
		tile = true,
		tileSize = 256,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	well:SetBackdropColor(1, 1, 1, 1)
	well:SetPoint("TOPLEFT", WELL_PAD, -TOP_BAR)
	well:SetPoint("BOTTOMRIGHT", -WELL_PAD, BOTTOM_BAR)
	window.well = well

	local content = CreateFrame("Frame", nil, window)
	content:SetFrameLevel((window:GetFrameLevel() or 1) + 2)
	content:SetPoint("TOPLEFT", CONTENT_INSET, -(TOP_BAR + CONTENT_V_INSET))
	content:SetPoint("BOTTOMRIGHT", -CONTENT_INSET, BOTTOM_BAR + CONTENT_V_INSET)
	function content:IsCombinedBagContainer()
		return false
	end
	function content:GetID()
		return 0
	end
	window.content = content
	window.TOP_BAR = TOP_BAR
	window.BOTTOM_BAR = BOTTOM_BAR
	window.PAD = PAD
	window.CONTENT_INSET = CONTENT_INSET
	window.CONTENT_V_INSET = CONTENT_V_INSET

	RestorePosition()
	HookBagToggles()
	HookCache()

	window:SetScript("OnEvent", function(_, event)
		if not ns.IsEnabled() then
			return
		end
		if event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
			ns.ReflowFooter()
			return
		end
		if ns.IsWindowShown() then
			ns.RefreshBags()
		end
	end)
	window:RegisterEvent("BAG_UPDATE_COOLDOWN")
	window:RegisterEvent("ITEM_LOCK_CHANGED")
	window:RegisterEvent("PLAYER_MONEY")
	window:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	window:RegisterEvent("INVENTORY_SEARCH_UPDATE")
	window:RegisterEvent("QUEST_ACCEPTED")
	window:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	window:RegisterEvent("PLAYER_REGEN_ENABLED")
	window:RegisterEvent("MERCHANT_SHOW")
	window:RegisterEvent("MERCHANT_CLOSED")

	return true
end
