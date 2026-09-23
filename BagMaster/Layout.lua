local _, ns = ...

ns.COLUMNS = 10
ns.ITEM_SIZE = 37
ns.ITEM_SPACING_X = 2
ns.ITEM_SPACING_Y = 2
ns.HEADER_HEIGHT = 18
ns.HEADER_GAP = 3
ns.SECTION_GAP = 10
ns.HEADER_NAME_MAX = 18

local headers = {}
local buttons = {}
local usedButtons = 0

local function GetBagName(bagID)
	local name = C_Container.GetBagName(bagID)
	if name and name ~= "" then
		return name
	end
	if bagID == 0 and BAG_NAME_BACKPACK then
		return BAG_NAME_BACKPACK
	end
	return "Bag " .. tostring(bagID)
end

local function GetBagIcon(bagID)
	if bagID and bagID > 0 and C_Container.ContainerIDToInventoryID and GetInventoryItemTexture then
		local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
		if inventoryID then
			local texture = GetInventoryItemTexture("player", inventoryID)
			if texture then
				return texture
			end
		end
	end
	return "Interface/Icons/Inv_misc_bag_08"
end

local function FirstBagIndex()
	if Enum and Enum.BagIndex and Enum.BagIndex.Backpack then
		return Enum.BagIndex.Backpack
	end
	return 0
end

local function LastBagIndex()
	return NUM_TOTAL_BAG_FRAMES or NUM_BAG_SLOTS or 4
end

local function EachSlot(callback)
	for bag = FirstBagIndex(), LastBagIndex() do
		local slots = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			callback(bag, slot)
		end
	end
end

local function SlotQuality(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if info and info.quality ~= nil then
		return info.quality
	end
	return -1
end

local function SortSlots(a, b)
	local qa = SlotQuality(a.bag, a.slot)
	local qb = SlotQuality(b.bag, b.slot)
	if qa ~= qb then
		return qa > qb
	end
	if a.bag ~= b.bag then
		return a.bag > b.bag
	end
	return a.slot > b.slot
end

local function GroupSlotsByBag()
	local byBag = {}
	local bagIDs = {}
	EachSlot(function(bag, slot)
		if not byBag[bag] then
			byBag[bag] = {}
			bagIDs[#bagIDs + 1] = bag
		end
		byBag[bag][#byBag[bag] + 1] = { bag = bag, slot = slot }
	end)
	table.sort(bagIDs, function(a, b)
		return a > b
	end)
	local sections = {}
	for i = 1, #bagIDs do
		local bagID = bagIDs[i]
		table.sort(byBag[bagID], function(a, b)
			return a.slot > b.slot
		end)
		sections[#sections + 1] = {
			title = GetBagName(bagID),
			icon = GetBagIcon(bagID),
			slots = byBag[bagID],
		}
	end
	return sections
end

local function GroupSlotsByCategory()
	local byKey = {}
	EachSlot(function(bag, slot)
		local key = ns.ClassifySlot(bag, slot)
		if not byKey[key] then
			byKey[key] = {}
		end
		byKey[key][#byKey[key] + 1] = { bag = bag, slot = slot }
	end)
	local sections = {}
	for i = 1, #ns.CATEGORIES do
		local meta = ns.CATEGORIES[i]
		local slots = byKey[meta.key]
		if slots and #slots > 0 then
			table.sort(slots, SortSlots)
			sections[#sections + 1] = {
				title = meta.title,
				icon = meta.icon,
				slots = slots,
			}
		end
	end
	return sections
end

local function GetSections()
	if ns.GetLayout() == "bags" then
		return GroupSlotsByBag()
	end
	return GroupSlotsByCategory()
end

local function GridHeight(slotCount)
	if slotCount <= 0 then
		return 0
	end
	local rows = math.ceil(slotCount / ns.COLUMNS)
	return (rows * ns.ITEM_SIZE) + ((rows - 1) * ns.ITEM_SPACING_Y)
end

local function AcquireHeader(parent, index)
	local header = headers[index]
	if header then
		header:SetParent(parent)
		header:Show()
		return header
	end
	header = CreateFrame("Frame", nil, parent)
	header:SetHeight(ns.HEADER_HEIGHT)
	header:EnableMouse(false)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.text:SetPoint("LEFT", 0, 1)
	header.text:SetJustifyH("LEFT")
	header.text:SetTextColor(0.78, 0.7, 0.45)
	header.line = header:CreateTexture(nil, "ARTWORK")
	header.line:SetColorTexture(1, 1, 1, 0.1)
	header.line:SetHeight(1)
	header.line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headers[index] = header
	return header
end

function ns.HideHeaders()
	for i = 1, #headers do
		headers[i]:Hide()
	end
end

local function AcquireButton(parent, index)
	local button = buttons[index]
	if button then
		button:SetParent(parent)
		button:Show()
		return button
	end
	button = CreateFrame("ItemButton", "BagMasterItem" .. index, parent, "ContainerFrameItemButtonTemplate")
	button:SetSize(ns.ITEM_SIZE, ns.ITEM_SIZE)
	if button.ItemSlotBackground then
		button.ItemSlotBackground:Hide()
	end
	if button.UpgradeIcon then
		button.UpgradeIcon:Hide()
	end
	if button.flash then
		button.flash:SetAlpha(0)
	end
	if button.BattlepayItemTexture then
		button.BattlepayItemTexture:Hide()
	end
	buttons[index] = button
	return button
end

local function AssignSlot(button, bag, slot)
	button.bagID = bag
	if button.SetBagID and not InCombatLockdown() then
		button:SetBagID(bag)
	end
	button:SetID(slot)
	button:Show()
end

local function UpdateButton(button)
	local bagID = button:GetBagID()
	local slot = button:GetID()
	local info = C_Container.GetContainerItemInfo(bagID, slot)
	local texture = info and info.iconFileID
	local itemCount = info and info.stackCount
	local locked = info and info.isLocked
	local quality = info and info.quality
	local itemLink = info and info.hyperlink
	local isFiltered = info and info.isFiltered
	local noValue = info and info.hasNoValue
	local isBound = info and info.isBound
	local readable = info and info.isReadable
	local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
	local isQuestItem = questInfo and questInfo.isQuestItem
	local questID = questInfo and questInfo.questID
	local isActive = questInfo and questInfo.isActive

	if ClearItemButtonOverlay then
		ClearItemButtonOverlay(button)
	end
	if button.SetHasItem then
		button:SetHasItem(texture)
	end
	if button.SetItemButtonTexture then
		button:SetItemButtonTexture(texture)
	elseif SetItemButtonTexture then
		SetItemButtonTexture(button, texture)
	end
	if SetItemButtonQuality then
		SetItemButtonQuality(button, quality, itemLink, false, isBound)
	end
	if SetItemButtonCount then
		SetItemButtonCount(button, itemCount)
	end
	if SetItemButtonDesaturated then
		SetItemButtonDesaturated(button, locked)
	end
	if button.UpdateQuestItem then
		button:UpdateQuestItem(isQuestItem, questID, isActive)
	end
	if button.UpdateNewItem then
		button:UpdateNewItem(quality)
	end
	if button.UpdateJunkItem then
		button:UpdateJunkItem(quality, noValue)
	end
	if button.UpdateCooldown then
		button:UpdateCooldown(texture)
	end
	if button.SetReadable then
		button:SetReadable(readable)
	end
	if button.SetMatchesSearch then
		button:SetMatchesSearch(not isFiltered)
	end
end

function ns.ForEachItemButton(callback)
	for i = 1, usedButtons do
		callback(buttons[i])
	end
end

local function LayoutSections()
	local content = ns.GetContent()
	if not content or not ns.IsEnabled() then
		ns.HideHeaders()
		return
	end

	local sections = GetSections()
	if #sections == 0 then
		ns.HideHeaders()
		return
	end

	local columns = ns.COLUMNS
	local gridWidth = (columns * ns.ITEM_SIZE) + ((columns - 1) * ns.ITEM_SPACING_X)
	local offsetY = 0
	local headerIndex = 0
	usedButtons = 0

	for i = 1, #sections do
		local section = sections[i]
		headerIndex = headerIndex + 1
		local header = AcquireHeader(content, headerIndex)
		header:ClearAllPoints()
		header:SetSize(gridWidth, ns.HEADER_HEIGHT)
		header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offsetY)
		header.text:SetText(section.title)
		header:Show()
		offsetY = offsetY + ns.HEADER_HEIGHT + ns.HEADER_GAP

		local slots = section.slots
		for s = 1, #slots do
			usedButtons = usedButtons + 1
			local button = AcquireButton(content, usedButtons)
			AssignSlot(button, slots[s].bag, slots[s].slot)
			UpdateButton(button)
			local col = (s - 1) % columns
			local row = math.floor((s - 1) / columns)
			button:ClearAllPoints()
			button:SetPoint(
				"TOPLEFT",
				content,
				"TOPLEFT",
				col * (ns.ITEM_SIZE + ns.ITEM_SPACING_X),
				-(offsetY + row * (ns.ITEM_SIZE + ns.ITEM_SPACING_Y))
			)
		end
		offsetY = offsetY + GridHeight(#slots) + ns.SECTION_GAP
	end

	for i = headerIndex + 1, #headers do
		headers[i]:Hide()
	end
	for i = usedButtons + 1, #buttons do
		buttons[i]:Hide()
	end

	local window = ns.GetWindow()
	if window then
		local width = (window.PAD or 10) * 2 + gridWidth
		local height = (window.TOP_BAR or 54) + offsetY + (window.BOTTOM_BAR or 26)
		ns.SetWindowSize(width, math.max(height, 220))
	end

	if ns.ApplySearchKeywords then
		ns.ApplySearchKeywords()
	end
	if ns.RefreshBagHighlights then
		ns.RefreshBagHighlights()
	end
end

function ns.RefreshBags()
	if not ns.IsEnabled() then
		ns.HideWindow()
		return
	end
	if not ns.IsWindowShown() then
		return
	end
	LayoutSections()
	if ns.UpdateMoney then
		ns.UpdateMoney()
	end
end

function ns.InitLayout()
	return ns.InitWindow()
end
