local _, ns = ...

local window
local searchBox
local moneyText
local moneyFrame
local tokenBar
local hookedToggles = false
local cacheHooked = false
local originals = {}

local TOP_BAR = 32
local BOTTOM_BAR = 36
local PAD = 10
local FRAME_SCALE = 1
local MONEY_Y = 8
local CURRENCY_ROW = 16

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

local tokenButtons = {}

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

local function IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
end

local function Flag(value)
	if IsSecret(value) then
		return nil
	end
	if value == true then
		return true
	end
	if value == false then
		return false
	end
	return nil
end

local function HasAmount(quantity)
	if quantity == nil then
		return false
	end
	if IsSecret(quantity) then
		return true
	end
	local amount = tonumber(quantity)
	return amount ~= nil and amount > 0
end

local function CurrencyText(quantity)
	if IsSecret(quantity) then
		return quantity
	end
	if not quantity then
		return "0"
	end
	if BreakUpLargeNumbers then
		return BreakUpLargeNumbers(quantity)
	end
	return tostring(quantity)
end

local function EnsureTokenUI()
	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_TokenUI")
	elseif LoadAddOn then
		pcall(LoadAddOn, "Blizzard_TokenUI")
	end
end

local function EnsureTokenBar()
	if tokenBar or not window then
		return tokenBar
	end
	tokenBar = CreateFrame("Frame", "BagMasterTokenBar", window)
	tokenBar:SetFrameLevel((window:GetFrameLevel() or 1) + 40)
	return tokenBar
end

local function AcquireTokenButton(index)
	local button = tokenButtons[index]
	if button then
		return button
	end
	local parent = EnsureTokenBar() or window
	button = CreateFrame("Button", nil, parent)
	button:SetHeight(14)
	button.icon = button:CreateTexture(nil, "OVERLAY")
	button.icon:SetSize(14, 14)
	button.icon:SetPoint("RIGHT", 0, 0)
	button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.count:SetPoint("RIGHT", button.icon, "LEFT", -2, 0)
	button.count:SetJustifyH("RIGHT")
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.currencyID and GameTooltip.SetCurrencyByID then
			GameTooltip:SetCurrencyByID(self.currencyID)
		elseif self.backpackIndex and GameTooltip.SetBackpackToken then
			GameTooltip:SetBackpackToken(self.backpackIndex)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", function(self)
		if IsModifiedClick("CHATLINK") and self.currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
			local link = C_CurrencyInfo.GetCurrencyLink(self.currencyID)
			if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then
				return
			end
		end
		if CharacterFrame and CharacterFrame.ToggleTokenFrame then
			CharacterFrame:ToggleTokenFrame()
		end
	end)
	tokenButtons[index] = button
	return button
end

local function RememberCurrency(list, icon, quantity, currencyID)
	if #list >= 8 then
		return
	end
	list[#list + 1] = {
		icon = icon,
		quantity = quantity,
		currencyID = currencyID,
	}
end

local function ReadBackpackCurrency(index)
	if not C_CurrencyInfo or not C_CurrencyInfo.GetBackpackCurrencyInfo then
		return nil
	end
	local ok, info, quantity, icon, currencyID = pcall(C_CurrencyInfo.GetBackpackCurrencyInfo, index)
	if not ok or info == nil then
		return nil
	end
	if type(info) == "table" then
		return info.iconFileID, info.quantity, info.currencyTypesID
	end
	return icon, quantity, currencyID
end

local function WatchedCurrencies()
	local list = {}
	for index = 1, 20 do
		local icon, quantity, currencyID = ReadBackpackCurrency(index)
		if icon == nil and quantity == nil and currencyID == nil then
			break
		end
		local rowIndex = #list + 1
		RememberCurrency(list, icon, quantity, currencyID)
		if list[rowIndex] then
			list[rowIndex].backpackIndex = index
		end
	end
	return list
end

local function LoadCurrencyList()
	EnsureTokenUI()
	if not C_CurrencyInfo or not C_CurrencyInfo.ExpandCurrencyList or not C_CurrencyInfo.GetCurrencyListInfo then
		return
	end
	for _ = 1, 6 do
		local ok, size = pcall(C_CurrencyInfo.GetCurrencyListSize)
		if not ok or type(size) ~= "number" or size < 1 then
			return
		end
		if size > 200 then
			size = 200
		end
		local grew = false
		for index = 1, size do
			local infoOK, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
			if infoOK and type(info) == "table" and Flag(info.isHeader) and Flag(info.isHeaderExpanded) == false then
				pcall(C_CurrencyInfo.ExpandCurrencyList, index, true)
				grew = true
				break
			end
		end
		if not grew then
			return
		end
	end
end

local function OwnedCurrencies()
	local list = {}
	if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize or not C_CurrencyInfo.GetCurrencyListInfo then
		return list
	end
	LoadCurrencyList()
	local ok, size = pcall(C_CurrencyInfo.GetCurrencyListSize)
	if not ok or type(size) ~= "number" then
		return list
	end
	if size > 200 then
		size = 200
	end
	for index = 1, size do
		local infoOK, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
		if infoOK and type(info) == "table" and not Flag(info.isHeader) and not Flag(info.isTypeUnused) then
			if Flag(info.isShowInBackpack) or HasAmount(info.quantity) then
				RememberCurrency(list, info.iconFileID, info.quantity, info.currencyID)
			end
		end
		if #list >= 8 then
			break
		end
	end
	return list
end

local function AlreadyListed(list, currencyID)
	if currencyID == nil or IsSecret(currencyID) then
		return false
	end
	for index = 1, #list do
		local existing = list[index].currencyID
		if not IsSecret(existing) and existing == currencyID then
			return true
		end
	end
	return false
end

local function FillCurrencies()
	EnsureTokenUI()
	local list = WatchedCurrencies()
	local owned = OwnedCurrencies()
	for index = 1, #owned do
		if not AlreadyListed(list, owned[index].currencyID) then
			RememberCurrency(list, owned[index].icon, owned[index].quantity, owned[index].currencyID)
		end
	end
	local bar = EnsureTokenBar()
	for index = 1, #list do
		local row = list[index]
		local button = AcquireTokenButton(index)
		button:SetID(index)
		button.currencyID = row.currencyID
		button.backpackIndex = row.backpackIndex
		button.count:SetText(CurrencyText(row.quantity))
		button.icon:SetTexture(nil)
		if row.icon then
			pcall(button.icon.SetTexture, button.icon, row.icon)
			button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		button.icon:Show()
		local textWidth = 28
		if not IsSecret(row.quantity) then
			textWidth = button.count:GetStringWidth() or 28
		end
		if textWidth < 12 then
			textWidth = 28
		end
		button:SetWidth(textWidth + 18)
		button:Show()
	end
	for index = #list + 1, #tokenButtons do
		tokenButtons[index]:Hide()
	end
	if bar then
		if #list > 0 then
			bar:Show()
		else
			bar:Hide()
		end
	end
	return #list
end

function ns.LayoutFooter(width)
	if not window then
		return BOTTOM_BAR
	end
	UpdateMoney()
	local moneyAnchor = moneyFrame or moneyText
	if moneyText and not moneyFrame then
		moneyText:ClearAllPoints()
		moneyText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, MONEY_Y)
	end

	local shown = FillCurrencies()
	local bar = EnsureTokenBar()
	local rows = 0
	if bar and shown > 0 and moneyAnchor then
		local gap = 8
		local cursor = width - 16
		local row = 0
		local rowHeight = 0
		for index = shown, 1, -1 do
			local button = tokenButtons[index]
			local buttonWidth = button:GetWidth()
			if buttonWidth < 32 then
				buttonWidth = 48
			end
			if cursor - buttonWidth < 16 then
				row = row + 1
				cursor = width - 16
				rowHeight = 0
			end
			button:ClearAllPoints()
			button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -(width - 16 - cursor), row * CURRENCY_ROW)
			cursor = cursor - buttonWidth - gap
			if button:GetHeight() > rowHeight then
				rowHeight = button:GetHeight()
			end
		end
		rows = row + 1
		local barHeight = rows * CURRENCY_ROW
		bar:ClearAllPoints()
		bar:SetSize(math.max(width - 32, 32), barHeight)
		bar:SetPoint("BOTTOMRIGHT", moneyAnchor, "TOPRIGHT", 0, 4)
		bar:Show()
	end

	local moneyHeight = 16
	if moneyAnchor and moneyAnchor.GetHeight then
		local height = moneyAnchor:GetHeight()
		if height and height > 8 then
			moneyHeight = height
		end
	end
	local footer = MONEY_Y + moneyHeight + 8
	if rows > 0 then
		footer = footer + 4 + (rows * CURRENCY_ROW)
	end
	window.BOTTOM_BAR = footer
	if window.content then
		window.content:SetPoint("BOTTOMRIGHT", -PAD, footer)
	end
	if window.well then
		window.well:ClearAllPoints()
		window.well:SetPoint("TOPLEFT", 5, -TOP_BAR)
		window.well:SetPoint("BOTTOMRIGHT", -5, footer)
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
	ns.SetWindowSize(width, top + window.itemHeight + footer)
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
	window:SetSize(width, height)
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
	window:SetScale(FRAME_SCALE)
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
	window:SetScript("OnHide", SavePosition)
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

	searchBox = CreateFrame("EditBox", "BagMasterSearchBox", window, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", PAD, -5)
	searchBox:SetPoint("TOPRIGHT", close, "TOPLEFT", -70, -7)
	layoutButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
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
		moneyFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, MONEY_Y)
		moneyFrame:SetFrameLevel((window:GetFrameLevel() or 1) + 40)
		moneyFrame:Show()
	else
		moneyText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		moneyText:SetPoint("BOTTOMRIGHT", -16, MONEY_Y)
		moneyText:SetJustifyH("RIGHT")
	end
	window.moneyText = moneyText
	EnsureTokenBar()

	local well = CreateFrame("Frame", nil, window, "BackdropTemplate")
	well:SetFrameLevel((window:GetFrameLevel() or 1) + 1)
	well:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 8,
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	well:SetBackdropColor(0.22, 0.15, 0.09, 0.92)
	well:SetBackdropBorderColor(0.42, 0.30, 0.14, 0.65)
	well:SetPoint("TOPLEFT", 5, -TOP_BAR)
	well:SetPoint("BOTTOMRIGHT", -5, BOTTOM_BAR)
	window.well = well

	local content = CreateFrame("Frame", nil, window)
	content:SetFrameLevel((window:GetFrameLevel() or 1) + 2)
	content:SetPoint("TOPLEFT", PAD, -TOP_BAR)
	content:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM_BAR)
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
