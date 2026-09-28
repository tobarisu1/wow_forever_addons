local _, ns = ...

local BAGS = {}
local BANK = {}
local bagSet = {}
local bankSet = {}

local function BagID(name)
	local indexes = Enum and Enum.BagIndex
	if indexes then
		return indexes[name]
	end
	return nil
end

local function AddBag(list, set, bagID)
	if bagID == nil or set[bagID] then
		return
	end
	list[#list + 1] = bagID
	set[bagID] = true
end

local function AddNamedBag(list, set, name, fallback)
	local bagID = BagID(name)
	if bagID == nil then
		bagID = fallback
	end
	AddBag(list, set, bagID)
end

AddNamedBag(BAGS, bagSet, "Backpack", 0)
AddNamedBag(BAGS, bagSet, "Bag_1", 1)
AddNamedBag(BAGS, bagSet, "Bag_2", 2)
AddNamedBag(BAGS, bagSet, "Bag_3", 3)
AddNamedBag(BAGS, bagSet, "Bag_4", 4)

for tab = 1, 9 do
	AddNamedBag(BANK, bankSet, "CharacterBankTab_" .. tab)
end

if #BANK == 0 then
	AddNamedBag(BANK, bankSet, "Bank")
	local bagSlots = NUM_BAG_SLOTS or 4
	local bankSlots = NUM_BANKBAGSLOTS or 0
	for index = 1, bankSlots do
		AddBag(BANK, bankSet, bagSlots + index)
	end
end

local pendingBags = {}
local pendingBank = {}
local changedBags = {}
local changedBank = {}
local pendingLoads = {}
local waitingItems = 0
local updatePending = false
local scanning = false
local bankOpen = false
local started = false

local function IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
end

local function PlainNumber(value)
	if value == nil or IsSecret(value) then
		return nil
	end
	if type(value) == "number" then
		return value
	end
	local ok, number = pcall(tonumber, value)
	if ok and type(number) == "number" then
		return number
	end
	return nil
end

local function PlainString(value)
	if type(value) ~= "string" or value == "" or IsSecret(value) then
		return nil
	end
	return value
end

local function PlainBool(value)
	if type(value) ~= "boolean" or IsSecret(value) then
		return nil
	end
	return value
end

local function ItemReady(itemID)
	if not C_Item or not C_Item.IsItemDataCachedByID then
		return true
	end
	local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
	return ok and cached and true or false
end

local function ContainerInfo(bagID, slot)
	if not C_Container or not C_Container.GetContainerItemInfo then
		return nil
	end
	local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
	if not ok or type(info) ~= "table" then
		return nil
	end
	return info
end

local function SlotCount(bagID)
	if not C_Container or not C_Container.GetContainerNumSlots then
		return 0
	end
	local ok, count = pcall(C_Container.GetContainerNumSlots, bagID)
	if not ok then
		return 0
	end
	count = PlainNumber(count)
	if not count or count < 1 then
		return 0
	end
	if count > 98 then
		return 98
	end
	return count
end

local function BackpackID()
	local indexes = Enum and Enum.BagIndex
	if indexes and indexes.Backpack ~= nil then
		return indexes.Backpack
	end
	return 0
end

local function IsGearBag(bagID)
	if bagID == BackpackID() then
		return true
	end
	local first = BackpackID() + 1
	local last = first + (NUM_BAG_SLOTS or 4) - 1
	return bagID >= first and bagID <= last
end

-- Backpack is always carried. Other bag slots count only when a bag is equipped there.
local function BagIsCarried(bagID)
	if bagID == BackpackID() then
		return true
	end
	if not IsGearBag(bagID) then
		return false
	end
	if not C_Container or not C_Container.ContainerIDToInventoryID or not GetInventoryItemID then
		return SlotCount(bagID) > 0
	end
	local ok, inventoryID = pcall(C_Container.ContainerIDToInventoryID, bagID)
	if not ok then
		return false
	end
	inventoryID = PlainNumber(inventoryID)
	if not inventoryID then
		return false
	end
	local itemOK, itemID = pcall(GetInventoryItemID, "player", inventoryID)
	if not itemOK or itemID == nil then
		return false
	end
	if IsSecret(itemID) then
		return true
	end
	itemID = PlainNumber(itemID)
	return itemID ~= nil and itemID ~= 0
end

local function ForgetBag(row, bagID)
	if type(row.bags) ~= "table" then
		return
	end
	row.bags[bagID] = nil
	row.bags[tostring(bagID)] = nil
end

local function PruneUncarriedBags()
	local row = ns.CurrentRow()
	if not row or type(row.bags) ~= "table" then
		return
	end
	local keys = {}
	for key in pairs(row.bags) do
		keys[#keys + 1] = key
	end
	for i = 1, #keys do
		local bagID = PlainNumber(keys[i])
		if bagID == nil or not BagIsCarried(bagID) then
			row.bags[keys[i]] = nil
		end
	end
end

-- Persisted slot. Empty is {}. itemLocation is not stored.
local function SlotFromInfo(info)
	local itemID = PlainNumber(info and info.itemID)
	if not itemID or itemID == 0 then
		return nil
	end
	local slot = {
		itemID = itemID,
		itemCount = PlainNumber(info.stackCount) or 1,
	}
	local icon = PlainNumber(info.iconFileID)
	if icon then
		slot.iconTexture = icon
	end
	local link = PlainString(info.hyperlink)
	if link then
		slot.itemLink = link
	end
	local quality = PlainNumber(info.quality)
	if quality ~= nil then
		slot.quality = quality
	end
	local bound = PlainBool(info.isBound)
	if bound ~= nil then
		slot.isBound = bound
	end
	local loot = PlainBool(info.hasLoot)
	if loot ~= nil then
		slot.hasLoot = loot
	end
	return slot
end

local function ClassIsQuest(itemID)
	local questClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem
	if not questClass or not itemID or not C_Item or not C_Item.GetItemInfoInstant then
		return false
	end
	local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
	if not ok then
		return false
	end
	classID = PlainNumber(classID)
	return classID == questClass
end

local function MarkQuest(slotRecord, bagID, slotIndex, itemID)
	if type(slotRecord) ~= "table" then
		return
	end
	local quest = false
	if C_Container and C_Container.GetContainerItemQuestInfo then
		local ok, questInfo = pcall(C_Container.GetContainerItemQuestInfo, bagID, slotIndex)
		if ok and type(questInfo) == "table" then
			local questItem = PlainBool(questInfo.isQuestItem)
			local questID = PlainNumber(questInfo.questID)
			if questItem or (questID and questID ~= 0) then
				quest = true
			end
		end
	end
	if not quest and ClassIsQuest(itemID) then
		quest = true
	end
	if quest then
		slotRecord.isQuestItem = true
	else
		slotRecord.isQuestItem = nil
	end
end

local loadFrame = CreateFrame("Frame")
local scanFrame = CreateFrame("Frame")

local function StopLoadWatchIfIdle()
	if waitingItems > 0 or next(pendingLoads) ~= nil then
		return
	end
	loadFrame:SetScript("OnUpdate", nil)
	loadFrame:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
end

local function FireIfIdle()
	if scanning or waitingItems > 0 then
		return
	end
	if next(pendingBags) ~= nil or next(pendingBank) ~= nil then
		updatePending = true
		scanFrame:SetScript("OnUpdate", scanFrame.RunScan)
		return
	end
	updatePending = false
	if next(changedBags) == nil and next(changedBank) == nil then
		return
	end
	local bags = changedBags
	local bank = changedBank
	changedBags = {}
	changedBank = {}
	if ns.currentCharacter and ns.Fire then
		ns.Fire("BagCacheUpdate", ns.currentCharacter, {
			bags = bags,
			bank = bank,
		})
	end
end

local function Deliver(itemID)
	local list = pendingLoads[itemID]
	if not list then
		return
	end
	pendingLoads[itemID] = nil
	for i = 1, #list do
		pcall(list[i])
		waitingItems = waitingItems - 1
	end
	if waitingItems < 0 then
		waitingItems = 0
	end
	StopLoadWatchIfIdle()
	FireIfIdle()
end

local function GiveUpLoads()
	local leftover = 0
	for _, list in pairs(pendingLoads) do
		leftover = leftover + #list
	end
	pendingLoads = {}
	waitingItems = waitingItems - leftover
	if waitingItems < 0 then
		waitingItems = 0
	end
	StopLoadWatchIfIdle()
	FireIfIdle()
end

local function WatchLoads()
	loadFrame.elapsed = 0
	loadFrame.tries = 0
	loadFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	loadFrame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed < 0.4 then
			return
		end
		self.elapsed = 0
		self.tries = (self.tries or 0) + 1
		local ids = {}
		for itemID in pairs(pendingLoads) do
			ids[#ids + 1] = itemID
		end
		if #ids == 0 then
			StopLoadWatchIfIdle()
			return
		end
		if self.tries > 8 then
			self:SetScript("OnUpdate", nil)
			GiveUpLoads()
			return
		end
		for i = 1, #ids do
			local itemID = ids[i]
			if ItemReady(itemID) then
				Deliver(itemID)
			elseif C_Item and C_Item.RequestLoadItemDataByID then
				pcall(C_Item.RequestLoadItemDataByID, itemID)
			end
		end
	end)
end

local function RequestItem(itemID, callback)
	waitingItems = waitingItems + 1
	local list = pendingLoads[itemID]
	if not list then
		list = {}
		pendingLoads[itemID] = list
	end
	list[#list + 1] = callback
	if C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
	WatchLoads()
end

loadFrame:SetScript("OnEvent", function(_, _, itemID)
	local id = PlainNumber(itemID)
	if id then
		Deliver(id)
	end
end)

local function ScanBag(bagID, kind)
	local row = ns.CurrentRow()
	if not row then
		return
	end
	if type(row[kind]) ~= "table" then
		row[kind] = {}
	end
	if kind == "bags" and not BagIsCarried(bagID) then
		ForgetBag(row, bagID)
		return
	end
	local slots = {}
	row[kind][bagID] = slots
	local count = SlotCount(bagID)
	for slot = 1, count do
		slots[slot] = {}
		local info = ContainerInfo(bagID, slot)
		local itemID = PlainNumber(info and info.itemID)
		if itemID and itemID ~= 0 then
			local written = SlotFromInfo(info)
			if written then
				MarkQuest(written, bagID, slot, itemID)
				slots[slot] = written
			end
			if not ItemReady(itemID) then
				RequestItem(itemID, function()
					local fresh = ContainerInfo(bagID, slot)
					if PlainNumber(fresh and fresh.itemID) == itemID then
						local filled = SlotFromInfo(fresh)
						if filled then
							MarkQuest(filled, bagID, slot, itemID)
							slots[slot] = filled
						end
					end
				end)
			end
		end
	end
end

function scanFrame:RunScan()
	self:SetScript("OnUpdate", nil)
	scanning = true
	local bags = pendingBags
	local bank = pendingBank
	pendingBags = {}
	pendingBank = {}
	PruneUncarriedBags()
	for bagID in pairs(bags) do
		ScanBag(bagID, "bags")
	end
	for bagID in pairs(bank) do
		ScanBag(bagID, "bank")
	end
	scanning = false
	FireIfIdle()
end

local function QueueBag(bagID, pending, changed)
	pending[bagID] = true
	changed[bagID] = true
	updatePending = true
	scanFrame:SetScript("OnUpdate", scanFrame.RunScan)
end

function ns.BagEventPending()
	return updatePending or waitingItems > 0
end

function ns.StartCache()
	if not started then
		started = true
		scanFrame:RegisterEvent("BAG_UPDATE")
		scanFrame:RegisterEvent("BAG_CONTAINER_UPDATE")
		scanFrame:RegisterEvent("BANKFRAME_OPENED")
		scanFrame:RegisterEvent("BANKFRAME_CLOSED")
		scanFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	end
	for i = 1, #BAGS do
		QueueBag(BAGS[i], pendingBags, changedBags)
	end
end

scanFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "BAG_UPDATE" then
		local bagID = PlainNumber(arg1)
		if not bagID then
			return
		end
		if bagSet[bagID] then
			QueueBag(bagID, pendingBags, changedBags)
		elseif bankOpen and bankSet[bagID] then
			QueueBag(bagID, pendingBank, changedBank)
		end
	elseif event == "BAG_CONTAINER_UPDATE" then
		for i = 1, #BAGS do
			QueueBag(BAGS[i], pendingBags, changedBags)
		end
		if bankOpen then
			for i = 1, #BANK do
				QueueBag(BANK[i], pendingBank, changedBank)
			end
		end
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		for i = 1, #BANK do
			QueueBag(BANK[i], pendingBank, changedBank)
		end
	elseif event == "BANKFRAME_CLOSED" then
		bankOpen = false
	elseif event == "PLAYERBANKSLOTS_CHANGED" then
		if not bankOpen then
			return
		end
		for i = 1, #BANK do
			QueueBag(BANK[i], pendingBank, changedBank)
		end
	end
end)
