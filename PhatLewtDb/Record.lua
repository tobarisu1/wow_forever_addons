local _, ns = ...

local captured = false
local fromItem = false
local pending = nil
local recentBoss = nil
local recentBossAt = 0
local lastMob = nil
local waiting = {}
local started = false

local function ClassIDs()
	local classes = Enum and Enum.ItemClass
	if not classes then
		return nil
	end
	return classes
end

local function BagSlot(containers, itemID)
	if type(containers) ~= "table" then
		return nil
	end
	for _, slots in pairs(containers) do
		if type(slots) == "table" then
			for _, slot in pairs(slots) do
				if type(slot) == "table" and slot.itemID == itemID then
					return slot
				end
			end
		end
	end
	return nil
end

local function BagFacts(itemID)
	if type(BackendMaster) ~= "table" or type(BackendMaster.GetCharacter) ~= "function" then
		return nil
	end
	local fullName = ns.CurrentCharacter()
	if not fullName then
		return nil
	end
	local row = BackendMaster.GetCharacter(fullName)
	if type(row) ~= "table" then
		return nil
	end
	local slot = BagSlot(row.bags, itemID) or BagSlot(row.bank, itemID)
	if type(slot) ~= "table" then
		return nil
	end
	return {
		quality = ns.PlainNumber(slot.quality),
		quest = slot.isQuestItem and true or false,
		link = ns.PlainString(slot.itemLink),
		icon = ns.PlainIcon(slot.iconTexture),
	}
end

local function ItemDetails(itemID, link)
	local details = {
		icon = nil,
		name = nil,
		quality = nil,
		link = ns.PlainString(link),
		classID = nil,
		subclassID = nil,
		crafting = false,
		reagent = false,
		quest = false,
	}
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
		if ok then
			details.icon = ns.PlainIcon(icon)
		end
	end
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, _, _, _, _, icon, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemID)
		if ok then
			if not details.icon then
				details.icon = ns.PlainIcon(icon)
			end
			details.classID = ns.PlainNumber(classID)
			details.subclassID = ns.PlainNumber(subclassID)
		end
	end
	if C_Item and C_Item.GetItemInfo then
		local results = { pcall(C_Item.GetItemInfo, itemID) }
		if results[1] then
			details.name = ns.PlainString(results[2])
			if not details.link then
				details.link = ns.PlainString(results[3])
			end
			if details.quality == nil then
				details.quality = ns.PlainNumber(results[4])
			end
			if not details.icon then
				details.icon = ns.PlainIcon(results[11])
			end
			if details.classID == nil then
				details.classID = ns.PlainNumber(results[13])
			end
			if details.subclassID == nil then
				details.subclassID = ns.PlainNumber(results[14])
			end
			if ns.PlainBool(results[18]) then
				details.crafting = true
			end
		end
	end
	local classes = ClassIDs()
	if classes and details.classID == classes.Reagent then
		details.reagent = true
	end
	if classes and details.classID == classes.Tradegoods then
		details.crafting = true
	end
	if classes and details.classID == classes.Questitem then
		details.quest = true
	end
	local bag = BagFacts(itemID)
	if bag then
		if details.quality == nil then
			details.quality = bag.quality
		end
		if bag.quest then
			details.quest = true
		end
		if not details.link then
			details.link = bag.link
		end
		if not details.icon then
			details.icon = bag.icon
		end
	end
	return details
end

function ns.FillLoadedItem(itemID)
	if type(PhatLewtDbDB) ~= "table" or type(PhatLewtDbDB.zones) ~= "table" then
		return
	end
	local details = ItemDetails(itemID)
	for _, zone in pairs(PhatLewtDbDB.zones) do
		if type(zone) == "table" and type(zone.mobs) == "table" then
			for _, mob in pairs(zone.mobs) do
				local item = type(mob) == "table" and type(mob.items) == "table" and mob.items[itemID]
				if type(item) == "table" then
					if details.name then
						item.name = details.name
					end
					if details.quality ~= nil then
						item.quality = details.quality
					end
					if details.icon then
						item.icon = details.icon
					end
					if details.link then
						item.link = details.link
					end
					if details.classID ~= nil then
						item.classID = details.classID
					end
					if details.subclassID ~= nil then
						item.subclassID = details.subclassID
					end
					if details.quest then
						item.quest = true
					end
					if details.crafting then
						item.crafting = true
					end
					if details.reagent then
						item.reagent = true
					end
				end
			end
		end
	end
end

local function WatchItem(itemID, details)
	if details.icon and details.name then
		return
	end
	if waiting[itemID] then
		return
	end
	waiting[itemID] = true
	if C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
end

local loadFrame = CreateFrame("Frame")
loadFrame:SetScript("OnEvent", function(_, _, itemID)
	itemID = ns.PlainNumber(itemID)
	if not itemID or not waiting[itemID] then
		return
	end
	waiting[itemID] = nil
	ns.FillLoadedItem(itemID)
	if ns.RefreshList then
		ns.RefreshList()
	end
end)
loadFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

local function ItemIDFromLink(link)
	link = ns.PlainString(link)
	if not link then
		return nil
	end
	local id = string.match(link, "item:(%d+)")
	return tonumber(id)
end

local function ReadSlot(slot)
	if not GetLootSlotInfo then
		return nil
	end
	local ok, texture, itemName, quantity, currencyID, quality, _, isQuestItem, _, _, isCoin = pcall(GetLootSlotInfo, slot)
	if not ok then
		return nil
	end
	local slotType
	if GetLootSlotType then
		local typeOK, value = pcall(GetLootSlotType, slot)
		if typeOK then
			slotType = ns.PlainNumber(value)
		end
	end
	if slotType == 0 or slotType == 2 or slotType == 3 then
		return nil
	end
	local coin = ns.PlainBool(isCoin)
	local currency = ns.PlainNumber(currencyID)
	if coin or (currency and currency ~= 0) then
		return nil
	end
	local link
	if GetLootSlotLink then
		local linkOK, value = pcall(GetLootSlotLink, slot)
		if linkOK then
			link = ns.PlainString(value)
		end
	end
	local itemID = ItemIDFromLink(link)
	if not itemID and C_Item and C_Item.GetItemInfoInstant and link then
		local idOK, id = pcall(C_Item.GetItemInfoInstant, link)
		if idOK then
			itemID = ns.PlainNumber(id)
		end
	end
	if not itemID then
		return nil
	end
	return {
		itemID = itemID,
		name = ns.PlainString(itemName),
		quantity = ns.PlainNumber(quantity) or 1,
		quality = ns.PlainNumber(quality),
		icon = ns.PlainIcon(texture),
		link = link,
		quest = ns.PlainBool(isQuestItem) or false,
	}
end

local function ReadItems()
	local items = {}
	local seen = {}
	if not GetNumLootItems then
		return items
	end
	local ok, count = pcall(GetNumLootItems)
	if not ok then
		return items
	end
	count = ns.PlainNumber(count) or 0
	if count > 50 then
		count = 50
	end
	for slot = 1, count do
		local row = ReadSlot(slot)
		if row then
			local existing = seen[row.itemID]
			if existing then
				existing.quantity = existing.quantity + row.quantity
				if not existing.name then
					existing.name = row.name
				end
				if existing.quality == nil then
					existing.quality = row.quality
				end
				if not existing.icon then
					existing.icon = row.icon
				end
				if not existing.link then
					existing.link = row.link
				end
				if row.quest then
					existing.quest = true
				end
			else
				seen[row.itemID] = row
				items[#items + 1] = row
			end
		end
	end
	return items
end

local function UnitToken(guid)
	if not guid or type(UnitTokenFromGUID) ~= "function" then
		return nil
	end
	local ok, token = pcall(UnitTokenFromGUID, guid)
	if not ok then
		return nil
	end
	return ns.PlainString(token)
end

local function NameFromGUID(guid)
	if not guid or type(UnitNameFromGUID) ~= "function" then
		return nil
	end
	local ok, name = pcall(UnitNameFromGUID, guid)
	if not ok then
		return nil
	end
	return ns.PlainString(name)
end

local function CreatureID(guid)
	if not guid or not C_CreatureInfo or not C_CreatureInfo.GetCreatureID then
		return nil
	end
	local ok, id = pcall(C_CreatureInfo.GetCreatureID, guid)
	if not ok then
		return nil
	end
	return ns.PlainNumber(id)
end

local function PlayerGUID()
	if type(UnitGUID) ~= "function" then
		return nil
	end
	local ok, guid = pcall(UnitGUID, "player")
	if not ok then
		return nil
	end
	return ns.PlainString(guid)
end

local function FirstLootGUID()
	if type(GetLootSourceInfo) ~= "function" or type(GetNumLootItems) ~= "function" then
		return nil
	end
	local ok, count = pcall(GetNumLootItems)
	if not ok then
		return nil
	end
	count = ns.PlainNumber(count) or 0
	if count > 50 then
		count = 50
	end
	for slot = 1, count do
		local sourceOK, guid = pcall(GetLootSourceInfo, slot)
		if sourceOK then
			guid = ns.PlainString(guid)
			if guid then
				return guid
			end
		end
	end
	return nil
end

local function DeadToken()
	if type(UnitExists) ~= "function" then
		return nil
	end
	local tokens = { "target", "mouseover", "focus", "softinteract", "softenemy" }
	for i = 1, #tokens do
		local token = tokens[i]
		local existsOK, exists = pcall(UnitExists, token)
		if existsOK and exists then
			local dead = false
			if UnitIsDead then
				local deadOK, value = pcall(UnitIsDead, token)
				dead = deadOK and value == true
			end
			if dead then
				return token
			end
		end
	end
	return nil
end

local function UnitNamePlain(token)
	if not token or type(UnitName) ~= "function" then
		return nil
	end
	local ok, name = pcall(UnitName, token)
	if not ok then
		return nil
	end
	return ns.PlainString(name)
end

local function IsWorldBoss(token)
	if not token or type(UnitClassification) ~= "function" then
		return false
	end
	local ok, kind = pcall(UnitClassification, token)
	if not ok then
		return false
	end
	return ns.PlainString(kind) == "worldboss"
end

local function FreshBoss()
	if not recentBoss or not GetTime then
		return nil
	end
	if GetTime() - recentBossAt > ns.BOSS_WINDOW then
		recentBoss = nil
		return nil
	end
	return recentBoss
end

local function RememberBoss(name)
	name = ns.PlainString(name)
	if not name or not GetTime then
		return
	end
	recentBoss = name
	recentBossAt = GetTime()
end

local function SameName(a, b)
	if not a or not b then
		return false
	end
	return string.lower(a) == string.lower(b)
end

local function ResolveSource(place)
	if fromItem then
		return {
			name = "Container",
			key = "container",
			boss = false,
		}
	end

	local guid = FirstLootGUID()
	local player = PlayerGUID()
	if guid and player and guid == player then
		return {
			name = "Gathered",
			key = "name:gathered",
			boss = false,
		}
	end

	local token = UnitToken(guid) or DeadToken()
	local name = NameFromGUID(guid) or UnitNamePlain(token)
	local npcID = CreatureID(guid)
	if not npcID and token and UnitGUID then
		local ok, unitGUID = pcall(UnitGUID, token)
		if ok then
			npcID = CreatureID(ns.PlainString(unitGUID))
		end
	end

	local boss = IsWorldBoss(token)
	local encounter = FreshBoss()
	if encounter and name and SameName(name, encounter) then
		boss = true
	end
	if (not name or name == "") and encounter and place.kind ~= "world" then
		name = encounter
		boss = true
	end
	if not name or name == "" then
		name = "Unknown"
	end

	local key
	if npcID then
		key = "npc:" .. npcID
	else
		key = "name:" .. string.lower(name)
	end
	return {
		name = name,
		key = key,
		npcID = npcID,
		boss = boss,
	}
end

local function FindMobKey(zone, source)
	local mobs = zone.mobs
	if mobs[source.key] then
		return source.key
	end
	local lower = string.lower(source.name)
	for key, mob in pairs(mobs) do
		if type(mob) == "table" and type(mob.name) == "string" and string.lower(mob.name) == lower then
			if source.npcID and not mob.npcID then
				mob.npcID = source.npcID
			end
			return key
		end
	end
	return source.key
end

local function EnsureZone(place)
	local zone = PhatLewtDbDB.zones[place.key]
	if type(zone) ~= "table" then
		zone = {}
		PhatLewtDbDB.zones[place.key] = zone
	end
	if type(zone.mobs) ~= "table" then
		zone.mobs = {}
	end
	if place.name and (place.name ~= "Unknown" or not zone.name) then
		zone.name = place.name
	end
	zone.kind = place.kind
	if place.mapID then
		zone.mapID = place.mapID
	end
	if place.instanceID then
		zone.instanceID = place.instanceID
	end
	return zone
end

local function EnsureMob(zone, key, source)
	local mob = zone.mobs[key]
	if type(mob) ~= "table" then
		mob = { opens = 0, items = {} }
		zone.mobs[key] = mob
	end
	if type(mob.items) ~= "table" then
		mob.items = {}
	end
	if type(mob.opens) ~= "number" then
		mob.opens = 0
	end
	if source.name and (source.name ~= "Unknown" or not mob.name) then
		mob.name = source.name
	end
	if source.npcID then
		mob.npcID = source.npcID
	end
	if source.boss then
		mob.boss = true
	end
	local character = ns.CurrentCharacter()
	if character then
		mob.lastCharacter = character
	end
	return mob
end

local function StoreItem(mob, row)
	local item = mob.items[row.itemID]
	if type(item) ~= "table" then
		item = { count = 0, quantity = 0 }
		mob.items[row.itemID] = item
	end
	if type(item.count) ~= "number" then
		item.count = 0
	end
	if type(item.quantity) ~= "number" then
		item.quantity = 0
	end
	local details = ItemDetails(row.itemID, row.link)
	if row.name then
		item.name = row.name
	elseif details.name then
		item.name = details.name
	end
	if row.quality ~= nil then
		item.quality = row.quality
	elseif details.quality ~= nil then
		item.quality = details.quality
	end
	item.icon = details.icon or row.icon or item.icon
	item.link = details.link or row.link or item.link
	if details.classID ~= nil then
		item.classID = details.classID
	end
	if details.subclassID ~= nil then
		item.subclassID = details.subclassID
	end
	if row.quest or details.quest then
		item.quest = true
	end
	if details.crafting then
		item.crafting = true
	end
	if details.reagent then
		item.reagent = true
	end
	item.count = item.count + 1
	item.quantity = item.quantity + (row.quantity or 1)
	WatchItem(row.itemID, details)
end

local function Commit(snapshot)
	if captured or not snapshot then
		return
	end
	captured = true
	pending = nil
	ns.InitDB()
	local place = snapshot.place or ns.CurrentPlace()
	local source = snapshot.source
	if fromItem then
		source = {
			name = "Container",
			key = "container",
			boss = false,
		}
	end
	local zone = EnsureZone(place)
	local key = FindMobKey(zone, source)
	local mob = EnsureMob(zone, key, source)
	mob.opens = mob.opens + 1
	lastMob = { zone = place.key, mob = key }
	for i = 1, #snapshot.items do
		StoreItem(mob, snapshot.items[i])
	end
	if ns.RefreshList then
		ns.RefreshList()
	end
end

function ns.AttachCharacter()
	local character = ns.CurrentCharacter()
	if not character or not lastMob then
		return
	end
	local zone = PhatLewtDbDB.zones[lastMob.zone]
	local mob = zone and zone.mobs and zone.mobs[lastMob.mob]
	if type(mob) == "table" and type(mob.lastCharacter) ~= "string" then
		mob.lastCharacter = character
	end
end

local function ReadSnapshot()
	return {
		place = ns.CurrentPlace(),
		source = ResolveSource(ns.CurrentPlace()),
		items = ReadItems(),
	}
end

local function RememberSlots()
	if captured then
		return
	end
	if pending and type(pending.items) == "table" and #pending.items > 0 then
		return
	end
	pending = ReadSnapshot()
end

local bossFrame = CreateFrame("Frame")
bossFrame:SetScript("OnEvent", function(_, event, _, encounterName, _, _, success)
	if event == "BOSS_KILL" then
		RememberBoss(encounterName)
	elseif event == "ENCOUNTER_END" then
		if ns.IsSecret(success) then
			return
		end
		if success == 1 or success == true then
			RememberBoss(encounterName)
		end
	end
end)

local lootFrame = CreateFrame("Frame")
lootFrame:SetScript("OnEvent", function(_, event, _, isFromItem)
	if event == "LOOT_READY" then
		RememberSlots()
	elseif event == "LOOT_OPENED" then
		fromItem = ns.PlainBool(isFromItem) or false
		RememberSlots()
		Commit(pending)
	elseif event == "LOOT_CLOSED" then
		if pending and not captured then
			Commit(pending)
		end
		captured = false
		fromItem = false
		pending = nil
	end
end)

function ns.InitRecord()
	if started then
		return
	end
	started = true
	lootFrame:RegisterEvent("LOOT_READY")
	lootFrame:RegisterEvent("LOOT_OPENED")
	lootFrame:RegisterEvent("LOOT_CLOSED")
	bossFrame:RegisterEvent("BOSS_KILL")
	bossFrame:RegisterEvent("ENCOUNTER_END")
end
