local _, ns = ...

ns.COLUMNS = 10
ns.ITEM_SIZE = 37
ns.ITEM_SPACING_X = 2
ns.ITEM_SPACING_Y = 2
ns.HEADER_HEIGHT = 20
ns.HEADER_GAP = 2
ns.SECTION_GAP = 8
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

local function BagTable()
	if type(Backend) ~= "table" or type(Backend.GetCurrentCharacter) ~= "function" or type(Backend.GetCharacter) ~= "function" then
		return nil
	end
	local fullName = Backend.GetCurrentCharacter()
	if type(fullName) ~= "string" then
		return nil
	end
	local row = Backend.GetCharacter(fullName)
	if type(row) ~= "table" or type(row.bags) ~= "table" then
		return nil
	end
	return row.bags
end

local function SlotEntry(slots, slotID)
	if type(slots) ~= "table" then
		return nil
	end
	local entry = slots[slotID]
	if type(entry) ~= "table" then
		entry = slots[tostring(slotID)]
	end
	if type(entry) ~= "table" then
		return nil
	end
	return entry
end

function ns.GetCachedSlot(bagID, slotID)
	bagID = tonumber(bagID)
	slotID = tonumber(slotID)
	if bagID == nil or slotID == nil then
		return nil
	end
	local bags = BagTable()
	if not bags then
		return nil
	end
	local slots = bags[bagID]
	if type(slots) ~= "table" then
		slots = bags[tostring(bagID)]
	end
	return SlotEntry(slots, slotID)
end

local function EachSlot(callback)
	local bags = BagTable()
	if not bags then
		return
	end
	local bagIDs = {}
	local seenBag = {}
	for key in pairs(bags) do
		local bagID = tonumber(key)
		if bagID ~= nil and not seenBag[bagID] then
			seenBag[bagID] = true
			bagIDs[#bagIDs + 1] = bagID
		end
	end
	table.sort(bagIDs, function(a, b)
		return a > b
	end)
	for i = 1, #bagIDs do
		local bagID = bagIDs[i]
		local slots = bags[bagID]
		if type(slots) ~= "table" then
			slots = bags[tostring(bagID)]
		end
		if type(slots) == "table" then
			local slotIDs = {}
			local seenSlot = {}
			for key in pairs(slots) do
				local slotID = tonumber(key)
				if slotID ~= nil and not seenSlot[slotID] then
					seenSlot[slotID] = true
					slotIDs[#slotIDs + 1] = slotID
				end
			end
			table.sort(slotIDs, function(a, b)
				return a > b
			end)
			for s = 1, #slotIDs do
				local slotID = slotIDs[s]
				callback(bagID, slotID, SlotEntry(slots, slotID) or {})
			end
		end
	end
end

local function SlotQuality(record)
	local entry = record and record.entry
	if type(entry) == "table" and type(entry.quality) == "number" then
		return entry.quality
	end
	return -1
end

local function SortSlots(a, b)
	local qa = SlotQuality(a)
	local qb = SlotQuality(b)
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
	EachSlot(function(bag, slot, entry)
		if not byBag[bag] then
			byBag[bag] = {}
			bagIDs[#bagIDs + 1] = bag
		end
		byBag[bag][#byBag[bag] + 1] = { bag = bag, slot = slot, entry = entry }
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
	EachSlot(function(bag, slot, entry)
		local key = ns.ClassifySlot(bag, slot)
		if not byKey[key] then
			byKey[key] = {}
		end
		byKey[key][#byKey[key] + 1] = { bag = bag, slot = slot, entry = entry }
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

local function MaxContentWidth()
	return (ns.COLUMNS * ns.ITEM_SIZE) + ((ns.COLUMNS - 1) * ns.ITEM_SPACING_X)
end

local function ColumnsForCount(count)
	if count <= 1 then
		return 1
	end
	local side = math.ceil(math.sqrt(count))
	if side > ns.COLUMNS then
		return ns.COLUMNS
	end
	return side
end

local function SectionBox(header, section)
	local count = #section.slots
	local cols = ColumnsForCount(count)
	local itemRows = math.ceil(count / cols)
	local gridWidth = (cols * ns.ITEM_SIZE) + ((cols - 1) * ns.ITEM_SPACING_X)
	local gridHeight = (itemRows * ns.ITEM_SIZE) + ((itemRows - 1) * ns.ITEM_SPACING_Y)
	local title = section.title or ""
	header.text:SetText(title)
	local titleWidth = math.ceil(header.text:GetStringWidth() or 0)
	if titleWidth < 1 then
		titleWidth = #title * 6
	end
	titleWidth = titleWidth + 4
	local maxWidth = MaxContentWidth()
	if titleWidth > maxWidth then
		titleWidth = maxWidth
	end
	local width = gridWidth
	if titleWidth > width then
		width = titleWidth
	end
	if width > maxWidth then
		width = maxWidth
	end
	return {
		section = section,
		cols = cols,
		width = width,
		height = ns.HEADER_HEIGHT + ns.HEADER_GAP + gridHeight,
	}
end

local function PackBoxes(boxes)
	local maxWidth = MaxContentWidth()
	local gap = ns.SECTION_GAP
	local packed = {}
	local row = nil
	local function PushRow()
		if row then
			packed[#packed + 1] = row
			row = nil
		end
	end
	for i = 1, #boxes do
		local box = boxes[i]
		if row and (row.width + gap + box.width) > maxWidth then
			PushRow()
		end
		if not row then
			row = { width = 0, height = 0, boxes = {} }
		end
		if row.width > 0 then
			row.width = row.width + gap
		end
		box.x = row.width
		row.width = row.width + box.width
		if box.height > row.height then
			row.height = box.height
		end
		row.boxes[#row.boxes + 1] = box
	end
	PushRow()
	return packed
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
	header.text:SetPoint("LEFT", 0, 0)
	header.text:SetPoint("RIGHT", 0, 0)
	header.text:SetJustifyH("LEFT")
	header.text:SetWordWrap(false)
	header.text:SetTextColor(1, 0.84, 0.45)
	header.line = header:CreateTexture(nil, "ARTWORK")
	header.line:SetTexture("Interface\\Common\\UI-TooltipDivider")
	header.line:SetHeight(8)
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
	button = CreateFrame("ItemButton", "BagMasterItem" .. index, parent, "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate")
	button:SetSize(ns.ITEM_SIZE, ns.ITEM_SIZE)
	button:SetAttribute("useOnKeyDown", false)
	button:SetScript("PostClick", function(self, mouseButton)
		if IsModifiedClick() then
			if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
				ContainerFrameItemButtonMixin.OnModifiedClick(self, mouseButton)
			end
			return
		end
		if mouseButton == "LeftButton" and C_Container and C_Container.PickupContainerItem then
			C_Container.PickupContainerItem(self:GetBagID(), self:GetID())
		end
	end)
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
	if InCombatLockdown() then
		return
	end
	if button.SetBagID then
		button:SetBagID(bag)
	end
	button:SetID(slot)
	local place = bag .. " " .. slot
	local noop = ATTRIBUTE_NOOP or ""
	button:SetAttribute("type2", "item")
	button:SetAttribute("item2", place)
	button:SetAttribute("shift-type2", noop)
	button:SetAttribute("ctrl-type2", noop)
	button:SetAttribute("alt-type2", noop)
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
end

function ns.ForEachItemButton(callback)
	for i = 1, usedButtons do
		callback(buttons[i])
	end
end

local function LayoutSections()
	local content = ns.GetContent()
	if not content or not ns.IsEnabled() then
		if not InCombatLockdown() then
			ns.HideHeaders()
		end
		return
	end
	if InCombatLockdown() then
		return
	end

	local sections = GetSections()
	if #sections == 0 then
		usedButtons = 0
		ns.HideHeaders()
		for i = 1, #buttons do
			buttons[i]:Hide()
		end
		return
	end

	local boxes = {}
	for i = 1, #sections do
		local header = AcquireHeader(content, i)
		boxes[i] = SectionBox(header, sections[i])
	end
	local packed = PackBoxes(boxes)
	local offsetY = 0
	local contentWidth = 0
	local headerIndex = 0
	usedButtons = 0
	local stepX = ns.ITEM_SIZE + ns.ITEM_SPACING_X
	local stepY = ns.ITEM_SIZE + ns.ITEM_SPACING_Y

	for r = 1, #packed do
		local band = packed[r]
		if band.width > contentWidth then
			contentWidth = band.width
		end
		for b = 1, #band.boxes do
			local box = band.boxes[b]
			headerIndex = headerIndex + 1
			local header = AcquireHeader(content, headerIndex)
			header:ClearAllPoints()
			header:SetSize(box.width, ns.HEADER_HEIGHT)
			header:SetPoint("TOPLEFT", content, "TOPLEFT", box.x, -offsetY)
			header.text:SetText(box.section.title)
			header:Show()

			local slots = box.section.slots
			local originY = offsetY + ns.HEADER_HEIGHT + ns.HEADER_GAP
			for s = 1, #slots do
				usedButtons = usedButtons + 1
				local button = AcquireButton(content, usedButtons)
				AssignSlot(button, slots[s].bag, slots[s].slot)
				UpdateButton(button)
				local col = (s - 1) % box.cols
				local itemRow = math.floor((s - 1) / box.cols)
				button:ClearAllPoints()
				button:SetPoint(
					"TOPLEFT",
					content,
					"TOPLEFT",
					box.x + (col * stepX),
					-(originY + (itemRow * stepY))
				)
			end
		end
		offsetY = offsetY + band.height
		if r < #packed then
			offsetY = offsetY + ns.SECTION_GAP
		end
	end

	for i = headerIndex + 1, #headers do
		headers[i]:Hide()
	end
	for i = usedButtons + 1, #buttons do
		buttons[i]:Hide()
	end

	local window = ns.GetWindow()
	if window then
		local pad = window.PAD or 8
		local width = (pad * 2) + contentWidth
		if width < 186 then
			width = 186
		end
		local height = (window.TOP_BAR or 36) + offsetY + (window.BOTTOM_BAR or 24)
		ns.SetWindowSize(width, height)
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
