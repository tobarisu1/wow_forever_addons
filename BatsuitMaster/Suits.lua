local _, ns = ...

-- Paper-doll slots. Inventory type numbers match Enum.InventoryType.
local HEAD, NECK, SHOULDER = 1, 2, 3
local SHIRT, CHEST, WAIST, LEGS, FEET, WRIST, HANDS = 4, 5, 6, 7, 8, 9, 10
local FINGER, TRINKET = 11, 12
local WEAPON, SHIELD, RANGED, CLOAK, WEAPON_2H = 13, 14, 15, 16, 17
local TABARD, ROBE = 19, 20
local WEAPON_MAIN, WEAPON_OFF, HOLDABLE = 21, 22, 23
local THROWN, RANGED_RIGHT = 25, 26

-- id is the paper-doll slot GetInventoryItemID and PickupInventoryItem use.
-- Table order is the button order on the sheet.
ns.SLOTS = {
	{ key = "Head", id = 1, token = "HeadSlot", side = "left", label = "Head", locs = { INVTYPE_HEAD = true } },
	{ key = "Neck", id = 2, token = "NeckSlot", side = "left", label = "Neck", locs = { INVTYPE_NECK = true } },
	{ key = "Shoulder", id = 3, token = "ShoulderSlot", side = "left", label = "Shoulder", locs = { INVTYPE_SHOULDER = true } },
	{ key = "Back", id = 15, token = "BackSlot", side = "left", label = "Back", locs = { INVTYPE_CLOAK = true } },
	{ key = "Chest", id = 5, token = "ChestSlot", side = "left", label = "Chest", locs = { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
	{ key = "Shirt", id = 4, token = "ShirtSlot", side = "left", label = "Shirt", locs = { INVTYPE_BODY = true } },
	{ key = "Tabard", id = 19, token = "TabardSlot", side = "left", label = "Tabard", locs = { INVTYPE_TABARD = true } },
	{ key = "Wrist", id = 9, token = "WristSlot", side = "left", label = "Wrist", locs = { INVTYPE_WRIST = true } },
	{ key = "Hands", id = 10, token = "HandsSlot", side = "right", label = "Hands", locs = { INVTYPE_HAND = true } },
	{ key = "Waist", id = 6, token = "WaistSlot", side = "right", label = "Waist", locs = { INVTYPE_WAIST = true } },
	{ key = "Legs", id = 7, token = "LegsSlot", side = "right", label = "Legs", locs = { INVTYPE_LEGS = true } },
	{ key = "Feet", id = 8, token = "FeetSlot", side = "right", label = "Feet", locs = { INVTYPE_FEET = true } },
	{ key = "Finger0", id = 11, token = "Finger0Slot", side = "right", label = "Finger", locs = { INVTYPE_FINGER = true } },
	{ key = "Finger1", id = 12, token = "Finger1Slot", side = "right", label = "Finger", locs = { INVTYPE_FINGER = true } },
	{ key = "Trinket0", id = 13, token = "Trinket0Slot", side = "right", label = "Trinket", locs = { INVTYPE_TRINKET = true } },
	{ key = "Trinket1", id = 14, token = "Trinket1Slot", side = "right", label = "Trinket", locs = { INVTYPE_TRINKET = true } },
	{ key = "MainHand", id = 16, token = "MainHandSlot", side = "weapon", label = "Main Hand", locs = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true } },
	{ key = "SecondaryHand", id = 17, token = "SecondaryHandSlot", side = "weapon", label = "Off Hand", locs = { INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true } },
	{ key = "Ranged", id = 18, token = "RangedSlot", side = "weapon", label = "Ranged", locs = { INVTYPE_RANGED = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true } },
}

local slotByKey = {}
for i = 1, #ns.SLOTS do
	slotByKey[ns.SLOTS[i].key] = ns.SLOTS[i]
end

local equipAfterCombat = false
local equipping = false

local function CharacterKey()
	if type(BackendMaster) == "table" and type(BackendMaster.GetCurrentCharacter) == "function" then
		local key = BackendMaster.GetCurrentCharacter()
		if type(key) == "string" and key ~= "" then
			return key
		end
	end
	return nil
end

local function DefaultSuit(index)
	return {
		name = "Suit " .. index,
		slots = {},
	}
end

local function CleanSuit(suit, index)
	if type(suit) ~= "table" then
		return DefaultSuit(index)
	end
	local name = ns.PlainString(suit.name)
	if not name then
		name = "Suit " .. index
	end
	if #name > 24 then
		name = string.sub(name, 1, 24)
	end
	local slots = {}
	if type(suit.slots) == "table" then
		for key, itemID in pairs(suit.slots) do
			itemID = ns.PlainNumber(itemID)
			if slotByKey[key] and itemID and itemID > 0 then
				slots[key] = itemID
			end
		end
	end
	suit.name = name
	suit.slots = slots
	return suit
end

function ns.EnsureCharacter()
	ns.InitDB()
	local key = CharacterKey()
	if not key then
		return nil
	end
	local row = BatsuitMasterDB.characters[key]
	if type(row) ~= "table" then
		row = {}
		BatsuitMasterDB.characters[key] = row
	end
	if type(row.suits) ~= "table" then
		row.suits = {}
	end
	for i = 1, ns.SUIT_COUNT do
		row.suits[i] = CleanSuit(row.suits[i], i)
	end
	local active = ns.PlainNumber(row.active)
	if not active or active < 1 or active > ns.SUIT_COUNT then
		row.active = 1
	else
		row.active = active
	end
	ns.characterKey = key
	return row
end

local function Row()
	return ns.EnsureCharacter()
end

function ns.ActiveIndex()
	local row = Row()
	if not row then
		return 1
	end
	return row.active
end

function ns.CurrentSuit()
	local row = Row()
	if not row then
		return DefaultSuit(1)
	end
	return row.suits[row.active]
end

function ns.SuitName(index)
	local row = Row()
	index = index or (row and row.active) or 1
	if row and row.suits[index] then
		return row.suits[index].name
	end
	return "Suit " .. index
end

function ns.SetActive(index)
	index = ns.PlainNumber(index)
	local row = Row()
	if not row or not index or index < 1 or index > ns.SUIT_COUNT then
		return
	end
	row.active = index
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

function ns.RenameSuit(text)
	local row = Row()
	if not row then
		return
	end
	text = ns.PlainString(text)
	if text then
		text = string.match(text, "^%s*(.-)%s*$")
	end
	if not text or text == "" then
		return
	end
	if #text > 24 then
		text = string.sub(text, 1, 24)
	end
	row.suits[row.active].name = text
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

function ns.SlotInfo(key)
	return slotByKey[key]
end

local function SlotQuery(token)
	if not GetInventorySlotInfo then
		return nil
	end
	local ok, id, texture = pcall(GetInventorySlotInfo, token)
	if (not ok or not ns.PlainNumber(id)) and token then
		ok, id, texture = pcall(GetInventorySlotInfo, string.upper(token))
	end
	if not ok then
		return nil
	end
	return ns.PlainNumber(id), texture
end

function ns.InventoryID(key)
	local info = slotByKey[key]
	return info and info.id or nil
end

function ns.EmptyTexture(key)
	local info = slotByKey[key]
	if not info then
		return nil
	end
	local _, texture = SlotQuery(info.token)
	if ns.IsSecret(texture) then
		return nil
	end
	if type(texture) == "number" or (type(texture) == "string" and texture ~= "") then
		return texture
	end
	return nil
end

-- Classic numbers, used only when the equip-location string is missing.
local NUMBER_TO_LOC = {
	[HEAD] = "INVTYPE_HEAD",
	[NECK] = "INVTYPE_NECK",
	[SHOULDER] = "INVTYPE_SHOULDER",
	[SHIRT] = "INVTYPE_BODY",
	[CHEST] = "INVTYPE_CHEST",
	[WAIST] = "INVTYPE_WAIST",
	[LEGS] = "INVTYPE_LEGS",
	[FEET] = "INVTYPE_FEET",
	[WRIST] = "INVTYPE_WRIST",
	[HANDS] = "INVTYPE_HAND",
	[FINGER] = "INVTYPE_FINGER",
	[TRINKET] = "INVTYPE_TRINKET",
	[WEAPON] = "INVTYPE_WEAPON",
	[SHIELD] = "INVTYPE_SHIELD",
	[RANGED] = "INVTYPE_RANGED",
	[CLOAK] = "INVTYPE_CLOAK",
	[WEAPON_2H] = "INVTYPE_2HWEAPON",
	[TABARD] = "INVTYPE_TABARD",
	[ROBE] = "INVTYPE_ROBE",
	[WEAPON_MAIN] = "INVTYPE_WEAPONMAINHAND",
	[WEAPON_OFF] = "INVTYPE_WEAPONOFFHAND",
	[HOLDABLE] = "INVTYPE_HOLDABLE",
	[THROWN] = "INVTYPE_THROWN",
	[RANGED_RIGHT] = "INVTYPE_RANGEDRIGHT",
}

local ENUM_TO_LOC = {
	IndexHeadType = "INVTYPE_HEAD",
	IndexNeckType = "INVTYPE_NECK",
	IndexShoulderType = "INVTYPE_SHOULDER",
	IndexBodyType = "INVTYPE_BODY",
	IndexChestType = "INVTYPE_CHEST",
	IndexWaistType = "INVTYPE_WAIST",
	IndexLegsType = "INVTYPE_LEGS",
	IndexFeetType = "INVTYPE_FEET",
	IndexWristType = "INVTYPE_WRIST",
	IndexHandType = "INVTYPE_HAND",
	IndexFingerType = "INVTYPE_FINGER",
	IndexTrinketType = "INVTYPE_TRINKET",
	IndexWeaponType = "INVTYPE_WEAPON",
	IndexShieldType = "INVTYPE_SHIELD",
	IndexRangedType = "INVTYPE_RANGED",
	IndexCloakType = "INVTYPE_CLOAK",
	Index2HweaponType = "INVTYPE_2HWEAPON",
	IndexTabardType = "INVTYPE_TABARD",
	IndexRobeType = "INVTYPE_ROBE",
	IndexWeaponmainhandType = "INVTYPE_WEAPONMAINHAND",
	IndexWeaponoffhandType = "INVTYPE_WEAPONOFFHAND",
	IndexHoldableType = "INVTYPE_HOLDABLE",
	IndexThrownType = "INVTYPE_THROWN",
	IndexRangedrightType = "INVTYPE_RANGEDRIGHT",
}

local function EquipLoc(itemID)
	itemID = ns.PlainNumber(itemID)
	if not itemID or not C_Item then
		return nil
	end
	if C_Item.GetItemInfoInstant then
		local results = { pcall(C_Item.GetItemInfoInstant, itemID) }
		if results[1] then
			for i = 2, #results do
				local value = results[i]
				if type(value) == "string" and not ns.IsSecret(value) and string.sub(value, 1, 8) == "INVTYPE_" then
					return value
				end
			end
		end
	end
	if not C_Item.GetItemInventoryType then
		return nil
	end
	local ok, invType = pcall(C_Item.GetItemInventoryType, itemID)
	if not ok or ns.IsSecret(invType) then
		return nil
	end
	if type(invType) == "string" and string.sub(invType, 1, 8) == "INVTYPE_" then
		return invType
	end
	local number = ns.PlainNumber(invType)
	if not number then
		return nil
	end
	if NUMBER_TO_LOC[number] then
		return NUMBER_TO_LOC[number]
	end
	local enum = Enum and Enum.InventoryType
	if type(enum) == "table" then
		for name, value in pairs(enum) do
			if value == number and ENUM_TO_LOC[name] then
				return ENUM_TO_LOC[name]
			end
		end
	end
	return nil
end

function ns.ItemFitsSlot(key, itemID)
	local info = slotByKey[key]
	local loc = EquipLoc(itemID)
	if not info or not loc then
		return false
	end
	return info.locs[loc] == true
end

local function CharacterRow()
	if type(BackendMaster) ~= "table" or type(BackendMaster.GetCharacter) ~= "function" then
		return nil
	end
	local key = CharacterKey()
	if not key then
		return nil
	end
	return BackendMaster.GetCharacter(key)
end

function ns.ForEachItem(kind, callback)
	local row = CharacterRow()
	local container = row and row[kind]
	if type(container) ~= "table" then
		return
	end
	for bagKey, slots in pairs(container) do
		local bagID = ns.PlainNumber(bagKey)
		if bagID and type(slots) == "table" then
			for slotKey, entry in pairs(slots) do
				local slotIndex = ns.PlainNumber(slotKey)
				local itemID = type(entry) == "table" and ns.PlainNumber(entry.itemID) or nil
				if slotIndex and itemID and itemID > 0 then
					callback(bagID, slotIndex, entry, itemID)
				end
			end
		end
	end
end

function ns.CountItems(kind, itemID)
	local total = 0
	ns.ForEachItem(kind, function(_, _, _, id)
		if id == itemID then
			total = total + 1
		end
	end)
	return total
end

function ns.ItemInBagsOrBank(itemID)
	return ns.CountItems("bags", itemID) + ns.CountItems("bank", itemID) > 0
end

function ns.LinkFor(itemID)
	local found
	local function take(_, _, entry, id)
		if id == itemID and not found then
			found = ns.PlainString(entry.itemLink)
		end
	end
	ns.ForEachItem("bags", take)
	if not found then
		ns.ForEachItem("bank", take)
	end
	if found then
		return found
	end
	return "item:" .. itemID
end

-- bags: a bag copy is assigned, in slot order.
-- worn: this paper-doll slot already has the item.
-- bank: only a bank copy is left.
-- missing: neither bags nor what you are wearing.
function ns.SlotPresence(key)
	local suit = ns.CurrentSuit()
	local itemID = suit.slots[key]
	if not itemID then
		return nil
	end
	if ns.WornItem(key) == itemID then
		return "worn"
	end
	local before = 0
	for i = 1, #ns.SLOTS do
		local slotKey = ns.SLOTS[i].key
		if slotKey == key then
			break
		end
		if suit.slots[slotKey] == itemID and ns.WornItem(slotKey) ~= itemID then
			before = before + 1
		end
	end
	local bags = ns.CountItems("bags", itemID)
	if bags > before then
		return "bags"
	end
	local bankBefore = before - bags
	if bankBefore < 0 then
		bankBefore = 0
	end
	if ns.CountItems("bank", itemID) > bankBefore then
		return "bank"
	end
	return "missing"
end

function ns.CanSuitUp()
	local suit = ns.CurrentSuit()
	local need = {}
	local filled = 0
	for i = 1, #ns.SLOTS do
		local key = ns.SLOTS[i].key
		local itemID = suit.slots[key]
		if itemID then
			filled = filled + 1
			if ns.WornItem(key) ~= itemID then
				need[itemID] = (need[itemID] or 0) + 1
			end
		end
	end
	if filled == 0 then
		return false
	end
	for itemID, count in pairs(need) do
		if ns.CountItems("bags", itemID) < count then
			return false
		end
	end
	return true
end

function ns.ItemName(itemID)
	itemID = ns.PlainNumber(itemID)
	if not itemID then
		return "Item"
	end
	if C_Item and C_Item.GetItemNameByID then
		local ok, value = pcall(C_Item.GetItemNameByID, itemID)
		local name = ok and ns.PlainString(value)
		if name then
			return name
		end
	end
	if C_Item and C_Item.GetItemInfo then
		local ok, value = pcall(C_Item.GetItemInfo, itemID)
		local name = ok and ns.PlainString(value)
		if name then
			return name
		end
	end
	return "Item " .. itemID
end

function ns.MissingPieces()
	local suit = ns.CurrentSuit()
	local list = {}
	for i = 1, #ns.SLOTS do
		local info = ns.SLOTS[i]
		local itemID = suit.slots[info.key]
		if itemID then
			local where = ns.SlotPresence(info.key)
			if where ~= "bags" and where ~= "worn" then
				list[#list + 1] = {
					key = info.key,
					label = info.label,
					itemID = itemID,
					name = ns.ItemName(itemID),
					icon = ns.ItemIcon(itemID),
					where = where,
				}
			end
		end
	end
	return list
end

function ns.SuitBlockReason()
	local pieces = ns.MissingPieces()
	if #pieces == 0 then
		return nil
	end
	local lines = {}
	for i = 1, #pieces do
		local piece = pieces[i]
		if piece.where == "bank" then
			lines[#lines + 1] = piece.name .. " is in the bank."
		else
			lines[#lines + 1] = piece.name .. " is not in your bags."
		end
	end
	return table.concat(lines, " ")
end

function ns.SetSlot(key, itemID, fromCursor)
	local row = Row()
	itemID = ns.PlainNumber(itemID)
	if not row or not slotByKey[key] or not itemID then
		return false
	end
	if not ns.ItemFitsSlot(key, itemID) then
		ns.Print("That item does not go in this slot.")
		return false
	end
	-- A picked-up item is already in a bag or the bank. The cache can lag a click behind.
	if not fromCursor and not ns.ItemInBagsOrBank(itemID) then
		ns.Print("That item is not in your bags or bank.")
		return false
	end
	row.suits[row.active].slots[key] = itemID
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
	return true
end

function ns.ClearSlot(key)
	local row = Row()
	if not row or not slotByKey[key] then
		return
	end
	row.suits[row.active].slots[key] = nil
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

function ns.ChoicesForSlot(key)
	local seen = {}
	local list = {}
	local function add(kind)
		ns.ForEachItem(kind, function(_, _, entry, itemID)
			if not ns.ItemFitsSlot(key, itemID) then
				return
			end
			local row = seen[itemID]
			if not row then
				row = {
					itemID = itemID,
					bags = 0,
					bank = 0,
					icon = entry.iconTexture,
					link = ns.PlainString(entry.itemLink),
				}
				seen[itemID] = row
				list[#list + 1] = row
			end
			row[kind] = row[kind] + 1
			if not row.icon and entry.iconTexture then
				row.icon = entry.iconTexture
			end
		end)
	end
	add("bags")
	add("bank")
	for i = 1, #list do
		local row = list[i]
		local name
		if C_Item and C_Item.GetItemNameByID then
			local ok, value = pcall(C_Item.GetItemNameByID, row.itemID)
			if ok then
				name = ns.PlainString(value)
			end
		end
		if not name and C_Item and C_Item.GetItemInfo then
			local ok, value = pcall(C_Item.GetItemInfo, row.itemID)
			if ok then
				name = ns.PlainString(value)
			end
		end
		row.name = name or ("Item " .. row.itemID)
		if not row.icon and C_Item and C_Item.GetItemIconByID then
			local ok, icon = pcall(C_Item.GetItemIconByID, row.itemID)
			if ok and not ns.IsSecret(icon) then
				row.icon = icon
			end
		end
	end
	table.sort(list, function(a, b)
		local aBank = a.bags == 0
		local bBank = b.bags == 0
		if aBank ~= bBank then
			return not aBank
		end
		return a.name < b.name
	end)
	return list
end

function ns.WornItem(key)
	local inv = ns.InventoryID(key)
	if not inv then
		return nil
	end
	if GetInventoryItemID then
		local ok, itemID = pcall(GetInventoryItemID, "player", inv)
		local id = ok and ns.PlainNumber(itemID)
		if id and id > 0 then
			return id
		end
	end
	if GetInventoryItemLink then
		local ok, link = pcall(GetInventoryItemLink, "player", inv)
		if ok and type(link) == "string" and not ns.IsSecret(link) then
			return ns.PlainNumber(string.match(link, "item:(%d+)"))
		end
	end
	return nil
end

function ns.ItemIsWorn(itemID)
	itemID = ns.PlainNumber(itemID)
	if not itemID then
		return false
	end
	for i = 1, #ns.SLOTS do
		if ns.WornItem(ns.SLOTS[i].key) == itemID then
			return true
		end
	end
	return false
end

local function ConfirmedBag(itemID, used)
	local list = {}
	ns.ForEachItem("bags", function(bag, slot, _, id)
		if id == itemID then
			list[#list + 1] = { bag = bag, slot = slot }
		end
	end)
	table.sort(list, function(a, b)
		if a.bag == b.bag then
			return a.slot < b.slot
		end
		return a.bag < b.bag
	end)
	for i = 1, #list do
		local loc = list[i]
		local token = loc.bag .. ":" .. loc.slot
		if not used[token] and C_Container and C_Container.GetContainerItemInfo then
			local ok, info = pcall(C_Container.GetContainerItemInfo, loc.bag, loc.slot)
			local id = ok and type(info) == "table" and ns.PlainNumber(info.itemID) or nil
			if id == itemID then
				used[token] = true
				return loc
			end
		end
	end
	return nil
end

local function CarriedBagIDs()
	local bags = { 0, 1, 2, 3, 4 }
	local indexes = Enum and Enum.BagIndex
	if indexes then
		local named = {}
		local names = { "Backpack", "Bag_1", "Bag_2", "Bag_3", "Bag_4" }
		for i = 1, #names do
			local bagID = indexes[names[i]]
			if bagID ~= nil then
				named[#named + 1] = bagID
			end
		end
		if #named > 0 then
			bags = named
		end
	end
	return bags
end

function ns.FreeBagSlots()
	if not C_Container or not C_Container.GetContainerNumFreeSlots then
		return 0
	end
	local free = 0
	local bags = CarriedBagIDs()
	for i = 1, #bags do
		local results = { pcall(C_Container.GetContainerNumFreeSlots, bags[i]) }
		local count = results[1] and ns.PlainNumber(results[2])
		local family = ns.PlainNumber(results[3])
		if count and count > 0 and (family == nil or family == 0) then
			free = free + count
		end
	end
	return free
end

local function FirstOpenSlot()
	if not C_Container or not C_Container.GetContainerFreeSlots then
		return nil
	end
	local bags = CarriedBagIDs()
	for i = 1, #bags do
		local results = { pcall(C_Container.GetContainerNumFreeSlots, bags[i]) }
		local family = ns.PlainNumber(results[3])
		if family ~= nil and family ~= 0 then
			-- profession bags and quivers do not take gear
		else
			local ok, slots = pcall(C_Container.GetContainerFreeSlots, bags[i])
			local slot = ok and type(slots) == "table" and ns.PlainNumber(slots[1])
			if slot then
				return bags[i], slot
			end
		end
	end
	return nil
end

local function CursorBusy()
	return CursorHasItem and CursorHasItem()
end

local function BindPopupOpen()
	if not StaticPopup_Visible then
		return false
	end
	local names = { "EQUIP_BIND", "EQUIP_BIND_TRADEABLE", "EQUIP_BIND_REFUNDABLE" }
	for i = 1, #names do
		local ok, shown = pcall(StaticPopup_Visible, names[i])
		if ok and shown then
			return true
		end
	end
	return false
end

local function PutCursorAway(bag, slot)
	if not CursorBusy() or not C_Container or not C_Container.PickupContainerItem then
		return not CursorBusy()
	end
	if bag ~= nil and slot ~= nil then
		pcall(C_Container.PickupContainerItem, bag, slot)
	end
	if CursorBusy() then
		local openBag, openSlot = FirstOpenSlot()
		if openBag then
			pcall(C_Container.PickupContainerItem, openBag, openSlot)
		end
	end
	return not CursorBusy()
end

-- Wear exactly the loadout. Pieces already in the right slot stay there.
-- Everything else comes off into the bags.
function ns.BuildSuitPlan()
	if not ns.CanSuitUp() then
		return nil, "missing"
	end
	local suit = ns.CurrentSuit()
	local used = {}
	local equips = {}
	local clears = {}
	local needSpace = 0
	for i = 1, #ns.SLOTS do
		local key = ns.SLOTS[i].key
		local desired = suit.slots[key]
		local worn = ns.WornItem(key)
		local inv = ns.InventoryID(key)
		if not inv then
			return nil, "missing"
		end
		if desired and worn == desired then
			-- already the right piece
		elseif desired then
			local loc = ConfirmedBag(desired, used)
			if loc then
				equips[#equips + 1] = {
					kind = "equip",
					key = key,
					itemID = desired,
					bag = loc.bag,
					slot = loc.slot,
					inv = inv,
				}
				if not worn then
					needSpace = needSpace - 1
				end
			elseif not ns.ItemIsWorn(desired) then
				return nil, "missing"
			end
		elseif worn then
			clears[#clears + 1] = {
				kind = "clear",
				key = key,
				inv = inv,
			}
			needSpace = needSpace + 1
		end
	end
	if needSpace > ns.FreeBagSlots() then
		return nil, "full"
	end
	local plan = equips
	for i = 1, #clears do
		plan[#plan + 1] = clears[i]
	end
	return plan
end

local SWAP_WAIT = 0.5

local function StopSuit(message)
	equipping = false
	ns.Print(message)
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

-- One manual swap, split so each click lands before the next.
-- 1 pick up, 2 put it on, 3 drop whatever came off.
local function RunSuit(plan, index, phase)
	if not equipping then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		StopSuit("Combat interrupted Suit Up.")
		return
	end
	if BindPopupOpen() then
		StopSuit("A piece is bind on equip and has not been worn yet. Equip it and bind it first.")
		return
	end
	local step = plan[index]
	if not step then
		equipping = false
		ns.Print("Suited up in " .. ns.SuitName() .. ".")
		if ns.RefreshWindow then
			ns.RefreshWindow()
		end
		return
	end
	local function nextPhase(nextIndex, nextPhase)
		C_Timer.After(SWAP_WAIT, function()
			RunSuit(plan, nextIndex, nextPhase)
		end)
	end
	if step.kind == "clear" then
		if not ns.WornItem(step.key) then
			nextPhase(index + 1, 1)
			return
		end
		if phase == 1 then
			if PickupInventoryItem then
				pcall(PickupInventoryItem, step.inv)
			end
			nextPhase(index, 2)
			return
		end
		if not PutCursorAway() then
			if PickupInventoryItem then
				pcall(PickupInventoryItem, step.inv)
			end
			StopSuit("Your bags are full. Suit Up cannot take off the extra pieces.")
			return
		end
		nextPhase(index + 1, 1)
		return
	end
	if ns.WornItem(step.key) == step.itemID and not CursorBusy() then
		nextPhase(index + 1, 1)
		return
	end
	if phase == 1 then
		if C_Container and C_Container.PickupContainerItem then
			pcall(C_Container.PickupContainerItem, step.bag, step.slot)
		end
		nextPhase(index, 2)
		return
	end
	if phase == 2 then
		if PickupInventoryItem then
			pcall(PickupInventoryItem, step.inv)
		end
		nextPhase(index, 3)
		return
	end
	if not PutCursorAway(step.bag, step.slot) then
		StopSuit("Your bags are full. Suit Up cannot take off the extra pieces.")
		return
	end
	nextPhase(index + 1, 1)
end

function ns.SuitUp()
	if not ns.CanSuitUp() then
		ns.Print(ns.SuitBlockReason() or "Every piece has to be in your bags.")
		if ns.RefreshWindow then
			ns.RefreshWindow()
		end
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		equipAfterCombat = true
		ns.Print("In combat. Suiting up when combat ends.")
		return
	end
	equipAfterCombat = false
	local plan, reason = ns.BuildSuitPlan()
	if not plan then
		if reason == "full" then
			ns.Print("Your bags are full. Suit Up cannot take off the extra pieces.")
		else
			ns.Print(ns.SuitBlockReason() or "Every piece has to be in your bags.")
		end
		if ns.RefreshWindow then
			ns.RefreshWindow()
		end
		return
	end
	if #plan == 0 then
		ns.Print("Already wearing " .. ns.SuitName() .. ".")
		return
	end
	equipping = true
	RunSuit(plan, 1, 1)
end

function ns.OnLeavingCombat()
	if not equipAfterCombat then
		return
	end
	equipAfterCombat = false
	if not ns.CanSuitUp() then
		ns.Print(ns.SuitBlockReason() or "A piece left your bags. Suit Up is off until the loadout is complete.")
		if ns.RefreshWindow then
			ns.RefreshWindow()
		end
		return
	end
	ns.SuitUp()
end

function ns.ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
		if ok and not ns.IsSecret(icon) and icon then
			return icon
		end
	end
	local found
	local function take(_, _, entry, id)
		if id == itemID and not found and entry.iconTexture and not ns.IsSecret(entry.iconTexture) then
			found = entry.iconTexture
		end
	end
	ns.ForEachItem("bags", take)
	if not found then
		ns.ForEachItem("bank", take)
	end
	return found
end
