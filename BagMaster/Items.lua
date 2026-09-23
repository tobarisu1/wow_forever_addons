local _, ns = ...

local QUEST_ITEM_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem
local QUALITY_POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor
if QUALITY_POOR == nil then
	QUALITY_POOR = 0
end

local CLASS_TO_CATEGORY = {}
local function MapClass(enumName, category)
	local classID = Enum and Enum.ItemClass and Enum.ItemClass[enumName]
	if classID then
		CLASS_TO_CATEGORY[classID] = category
	end
end

MapClass("Consumable", "consumable")
MapClass("Weapon", "weapon")
MapClass("Armor", "armor")
MapClass("Reagent", "reagent")
MapClass("Tradegoods", "tradegoods")
MapClass("Recipe", "recipe")
MapClass("Projectile", "projectile")
MapClass("Key", "key")

ns.CATEGORIES = {
	{ key = "quest", title = "Quest", icon = "Interface/Icons/INV_Misc_Book_09" },
	{ key = "consumable", title = "Consumable", icon = "Interface/Icons/INV_Potion_52" },
	{ key = "weapon", title = "Weapon", icon = "Interface/Icons/INV_Sword_04" },
	{ key = "armor", title = "Armor", icon = "Interface/Icons/INV_Chest_Chain" },
	{ key = "reagent", title = "Reagent", icon = "Interface/Icons/INV_Misc_Herb_07" },
	{ key = "tradegoods", title = "Trade Goods", icon = "Interface/Icons/INV_Fabric_Silk_01" },
	{ key = "recipe", title = "Recipe", icon = "Interface/Icons/INV_Scroll_03" },
	{ key = "projectile", title = "Projectile", icon = "Interface/Icons/INV_Ammo_Arrow_02" },
	{ key = "key", title = "Key", icon = "Interface/Icons/INV_Misc_Key_03" },
	{ key = "other", title = "Other", icon = "Interface/Icons/INV_Misc_QuestionMark" },
	{ key = "junk", title = "Junk", icon = "Interface/Icons/INV_Misc_Coin_16" },
	{ key = "empty", title = "Empty", icon = "Interface/Icons/INV_Misc_Bag_08" },
}

local KEYWORDS = {
	quest = "quest",
	junk = "junk",
	empty = "empty",
	consumable = "consumable",
	weapon = "weapon",
	armor = "armor",
	reagent = "reagent",
	trade = "tradegoods",
	tradegoods = "tradegoods",
	recipe = "recipe",
	ammo = "projectile",
	projectile = "projectile",
	key = "key",
}

local itemsHooked = false

function ns.IsItemsEnabled()
	return ns.IsEnabled() and BagMasterDB and BagMasterDB.highlightItems
end

function ns.SlotIsQuestItem(bag, slot)
	if not bag or not slot or not C_Container then
		return false
	end
	if C_Container.GetContainerItemQuestInfo then
		local questInfo = C_Container.GetContainerItemQuestInfo(bag, slot)
		if questInfo and (questInfo.isQuestItem or questInfo.questID) then
			return true
		end
	end
	if not C_Container.GetContainerItemInfo then
		return false
	end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then
		return false
	end
	if info.classID and QUEST_ITEM_CLASS and info.classID == QUEST_ITEM_CLASS then
		return true
	end
	if C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
		if QUEST_ITEM_CLASS and classID == QUEST_ITEM_CLASS then
			return true
		end
	end
	return false
end

function ns.ClassifySlot(bag, slot)
	if not bag or not slot or not C_Container or not C_Container.GetContainerItemInfo then
		return "empty"
	end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then
		return "empty"
	end
	if ns.SlotIsQuestItem(bag, slot) then
		return "quest"
	end
	if info.quality == QUALITY_POOR then
		return "junk"
	end
	local classID = info.classID
	if not classID and C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, _, instantClass = C_Item.GetItemInfoInstant(info.itemID)
		classID = instantClass
	end
	return CLASS_TO_CATEGORY[classID] or "other"
end

local function EnsureItemHighlight(button)
	if button.OldManQuesterHL then
		button.OldManQuesterHL:Hide()
	end
	if button.BagMasterHL then
		return button.BagMasterHL
	end

	local hl = CreateFrame("Frame", nil, button)
	hl:SetAllPoints(button)
	hl:EnableMouse(false)

	local icon = button.Icon or button.icon
	local wash = hl:CreateTexture(nil, "ARTWORK")
	if icon then
		wash:SetAllPoints(icon)
	else
		wash:SetAllPoints(hl)
	end
	wash:SetTexture("Interface\\Buttons\\WHITE8X8")
	wash:SetVertexColor(1, 0.9, 0, 0.55)
	wash:SetBlendMode("ADD")
	hl.wash = wash

	local border = hl:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	border:SetBlendMode("ADD")
	border:SetVertexColor(1, 1, 0.15, 1)
	border:SetPoint("CENTER")
	hl.border = border

	local edge = CreateFrame("Frame", nil, hl, "BackdropTemplate")
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	edge:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 3,
	})
	edge:SetBackdropBorderColor(1, 1, 0, 1)
	edge:EnableMouse(false)
	hl.edge = edge

	button.BagMasterHL = hl
	return hl
end

local function HideItemHighlight(button)
	if button and button.BagMasterHL then
		button.BagMasterHL:Hide()
	end
	if button and button.OldManQuesterHL then
		button.OldManQuesterHL:Hide()
	end
end

local function ShowItemHighlight(button)
	local hl = EnsureItemHighlight(button)
	hl:SetFrameLevel(button:GetFrameLevel() + 1)
	local size = button:GetWidth()
	if size and size > 0 then
		hl.border:SetSize(size * 1.85, size * 1.85)
	end
	hl:Show()
end

local function ApplyItemHighlight(button)
	if not button then
		return
	end
	if not ns.IsItemsEnabled() then
		HideItemHighlight(button)
		return
	end

	local bag = button.GetBagID and button:GetBagID()
	local slot = button.GetID and button:GetID()
	if not ns.SlotIsQuestItem(bag, slot) then
		HideItemHighlight(button)
		return
	end
	ShowItemHighlight(button)
end

local function ForEachShownBagButton(callback)
	if ns.ForEachItemButton then
		ns.ForEachItemButton(callback)
		return
	end
	if not ContainerFrameSettingsManager or not ContainerFrameSettingsManager.GetBagsShown then
		return
	end
	local bags = ContainerFrameSettingsManager:GetBagsShown()
	if not bags then
		return
	end
	for i = 1, #bags do
		local bag = bags[i]
		if bag.EnumerateValidItems then
			for _, itemButton in bag:EnumerateValidItems() do
				callback(itemButton)
			end
		end
	end
end

function ns.RefreshBagHighlights()
	ForEachShownBagButton(ApplyItemHighlight)
end

local function OnBagQuestItemUpdate(button, isQuestItem, questID)
	if not ns.IsItemsEnabled() then
		HideItemHighlight(button)
		return
	end
	if isQuestItem or questID then
		ShowItemHighlight(button)
		return
	end
	ApplyItemHighlight(button)
end

function ns.SetItemsEnabled(enabled)
	BagMasterDB.highlightItems = enabled
	ns.RefreshBagHighlights()
	ns.Print("items " .. (ns.IsItemsEnabled() and "ON" or "OFF"))
	if enabled and not ns.IsEnabled() then
		ns.Print("Turn the addon on with /bm on to show highlights.")
	end
end

function ns.ApplySearchKeywords(query)
	if type(query) ~= "string" then
		query = ns.GetSearchQuery and ns.GetSearchQuery() or ""
	end
	local keyword = KEYWORDS[query]
	if not ns.ForEachItemButton then
		return
	end
	ns.ForEachItemButton(function(button)
		if not button.SetMatchesSearch then
			return
		end
		local bag = button.GetBagID and button:GetBagID()
		local slot = button.GetID and button:GetID()
		if query == "" then
			button:SetMatchesSearch(true)
			return
		end
		local info = C_Container.GetContainerItemInfo(bag, slot)
		local blizzardMatch = not (info and info.isFiltered)
		local matchesKeyword = keyword and ns.ClassifySlot(bag, slot) == keyword
		button:SetMatchesSearch(blizzardMatch or matchesKeyword)
	end)
end

function ns.InitItems()
	if itemsHooked then
		return true
	end
	if not ContainerFrameItemButtonMixin or not ContainerFrameItemButtonMixin.UpdateQuestItem then
		return false
	end
	itemsHooked = true
	hooksecurefunc(ContainerFrameItemButtonMixin, "UpdateQuestItem", OnBagQuestItemUpdate)
	if ContainerFrameMixin and ContainerFrameMixin.UpdateItems then
		hooksecurefunc(ContainerFrameMixin, "UpdateItems", ns.RefreshBagHighlights)
	end
	return true
end
