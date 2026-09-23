local _, ns = ...

local window
local searchBox
local moneyText
local hookedToggles = false
local originals = {}

local TOP_BAR = 36
local BOTTOM_BAR = 24
local PAD = 8

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
	if not moneyText then
		return
	end
	local amount = GetMoney() or 0
	if GetCoinTextureString then
		moneyText:SetText(GetCoinTextureString(amount))
	else
		moneyText:SetText(tostring(amount))
	end
end

function ns.UpdateMoney()
	UpdateMoney()
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
		return true
	end

	window = CreateFrame("Frame", "BagMasterFrame", UIParent, "BackdropTemplate")
	window:SetFrameStrata("MEDIUM")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetSize(420, 500)
	window:Hide()
	window:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	window:SetBackdropColor(0.08, 0.08, 0.09, 0.96)
	window:SetBackdropBorderColor(0.15, 0.15, 0.16, 1)
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

	local close = CreateFrame("Button", nil, window)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", -4, -8)
	close:SetNormalFontObject("GameFontHighlightSmall")
	close:SetHighlightFontObject("GameFontNormalSmall")
	close:SetText("x")
	close:SetScript("OnClick", function()
		ns.HideWindow()
	end)

	searchBox = CreateFrame("EditBox", "BagMasterSearchBox", window, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", PAD, -8)
	searchBox:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
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

	moneyText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	moneyText:SetPoint("BOTTOMRIGHT", -PAD, 7)
	moneyText:SetJustifyH("RIGHT")
	window.moneyText = moneyText

	local content = CreateFrame("Frame", nil, window)
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

	window:SetScript("OnEvent", function(_, event)
		if not ns.IsEnabled() then
			return
		end
		if event == "PLAYER_MONEY" then
			UpdateMoney()
			return
		end
		if ns.IsWindowShown() then
			ns.RefreshBags()
		end
	end)
	window:RegisterEvent("BAG_UPDATE_DELAYED")
	window:RegisterEvent("BAG_UPDATE_COOLDOWN")
	window:RegisterEvent("ITEM_LOCK_CHANGED")
	window:RegisterEvent("PLAYER_MONEY")
	window:RegisterEvent("INVENTORY_SEARCH_UPDATE")
	window:RegisterEvent("QUEST_ACCEPTED")
	window:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	window:RegisterEvent("PLAYER_REGEN_ENABLED")

	return true
end
