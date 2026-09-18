local _, ns = ...

local KIND_HERB = "herb"
local KIND_ORE = "ore"
local KIND_CHEST = "chest"

ns.DEFAULT_ICONS = {
	[KIND_HERB] = "Interface\\Icons\\INV_Misc_Flower_02",
	[KIND_ORE] = "Interface\\Icons\\INV_Ore_Copper_01",
	[KIND_CHEST] = "Interface\\Icons\\INV_Box_01",
}

-- Vanilla-era node names. itemID is the gathered item so pins use that icon.
local catalog = {
	-- Herbs
	{ name = "Peacebloom", kind = KIND_HERB, itemID = 2447, skill = 1, skillName = "Herbalism" },
	{ name = "Silverleaf", kind = KIND_HERB, itemID = 765, skill = 1, skillName = "Herbalism" },
	{ name = "Earthroot", kind = KIND_HERB, itemID = 2449, skill = 15, skillName = "Herbalism" },
	{ name = "Mageroyal", kind = KIND_HERB, itemID = 785, skill = 50, skillName = "Herbalism" },
	{ name = "Briarthorn", kind = KIND_HERB, itemID = 2450, skill = 70, skillName = "Herbalism" },
	{ name = "Stranglekelp", kind = KIND_HERB, itemID = 3820, skill = 85, skillName = "Herbalism" },
	{ name = "Bruiseweed", kind = KIND_HERB, itemID = 2453, skill = 100, skillName = "Herbalism" },
	{ name = "Wild Steelbloom", kind = KIND_HERB, itemID = 3355, skill = 115, skillName = "Herbalism" },
	{ name = "Grave Moss", kind = KIND_HERB, itemID = 3369, skill = 120, skillName = "Herbalism" },
	{ name = "Kingsblood", kind = KIND_HERB, itemID = 3356, skill = 125, skillName = "Herbalism" },
	{ name = "Liferoot", kind = KIND_HERB, itemID = 3357, skill = 150, skillName = "Herbalism" },
	{ name = "Fadeleaf", kind = KIND_HERB, itemID = 3818, skill = 160, skillName = "Herbalism" },
	{ name = "Goldthorn", kind = KIND_HERB, itemID = 3821, skill = 170, skillName = "Herbalism" },
	{ name = "Khadgar's Whisker", kind = KIND_HERB, itemID = 3358, skill = 185, skillName = "Herbalism" },
	{ name = "Wintersbite", kind = KIND_HERB, itemID = 3819, skill = 195, skillName = "Herbalism" },
	{ name = "Firebloom", kind = KIND_HERB, itemID = 4625, skill = 205, skillName = "Herbalism" },
	{ name = "Purple Lotus", kind = KIND_HERB, itemID = 8831, skill = 210, skillName = "Herbalism" },
	{ name = "Arthas' Tears", kind = KIND_HERB, itemID = 8836, skill = 220, skillName = "Herbalism" },
	{ name = "Sungrass", kind = KIND_HERB, itemID = 8838, skill = 230, skillName = "Herbalism" },
	{ name = "Blindweed", kind = KIND_HERB, itemID = 8839, skill = 235, skillName = "Herbalism" },
	{ name = "Ghost Mushroom", kind = KIND_HERB, itemID = 8845, skill = 245, skillName = "Herbalism" },
	{ name = "Gromsblood", kind = KIND_HERB, itemID = 8846, skill = 250, skillName = "Herbalism" },
	{ name = "Golden Sansam", kind = KIND_HERB, itemID = 13464, skill = 260, skillName = "Herbalism" },
	{ name = "Dreamfoil", kind = KIND_HERB, itemID = 13463, skill = 270, skillName = "Herbalism" },
	{ name = "Mountain Silversage", kind = KIND_HERB, itemID = 13465, skill = 280, skillName = "Herbalism" },
	{ name = "Plaguebloom", kind = KIND_HERB, itemID = 13466, skill = 285, skillName = "Herbalism" },
	{ name = "Icecap", kind = KIND_HERB, itemID = 13467, skill = 290, skillName = "Herbalism" },
	{ name = "Black Lotus", kind = KIND_HERB, itemID = 13468, skill = 300, skillName = "Herbalism" },

	-- Ore
	{ name = "Copper Vein", kind = KIND_ORE, itemID = 2770, skill = 1, skillName = "Mining" },
	{ name = "Tin Vein", kind = KIND_ORE, itemID = 2771, skill = 65, skillName = "Mining" },
	{ name = "Silver Vein", kind = KIND_ORE, itemID = 2775, skill = 75, skillName = "Mining" },
	{ name = "Iron Deposit", kind = KIND_ORE, itemID = 2772, skill = 125, skillName = "Mining" },
	{ name = "Gold Vein", kind = KIND_ORE, itemID = 2776, skill = 155, skillName = "Mining" },
	{ name = "Mithril Deposit", kind = KIND_ORE, itemID = 3858, skill = 175, skillName = "Mining" },
	{ name = "Truesilver Deposit", kind = KIND_ORE, itemID = 7911, skill = 230, skillName = "Mining" },
	{ name = "Dark Iron Deposit", kind = KIND_ORE, itemID = 11370, skill = 230, skillName = "Mining" },
	{ name = "Small Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 245, skillName = "Mining" },
	{ name = "Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 250, skillName = "Mining" },
	{ name = "Rich Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 275, skillName = "Mining" },
	{ name = "Ooze Covered Silver Vein", kind = KIND_ORE, itemID = 2775, skill = 75, skillName = "Mining" },
	{ name = "Ooze Covered Gold Vein", kind = KIND_ORE, itemID = 2776, skill = 155, skillName = "Mining" },
	{ name = "Ooze Covered Iron Deposit", kind = KIND_ORE, itemID = 2772, skill = 125, skillName = "Mining" },
	{ name = "Ooze Covered Mithril Deposit", kind = KIND_ORE, itemID = 3858, skill = 175, skillName = "Mining" },
	{ name = "Ooze Covered Truesilver Deposit", kind = KIND_ORE, itemID = 7911, skill = 230, skillName = "Mining" },
	{ name = "Ooze Covered Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 255, skillName = "Mining" },
	{ name = "Ooze Covered Rich Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 275, skillName = "Mining" },
	{ name = "Incendicite Mineral Vein", kind = KIND_ORE, itemID = 3340, skill = 65, skillName = "Mining" },
	{ name = "Lesser Bloodstone Deposit", kind = KIND_ORE, itemID = 4278, skill = 75, skillName = "Mining" },
	{ name = "Indurium Mineral Vein", kind = KIND_ORE, itemID = 5833, skill = 150, skillName = "Mining" },
	{ name = "Hakkari Thorium Vein", kind = KIND_ORE, itemID = 10620, skill = 250, skillName = "Mining" },

	-- Chests (no gathered item; use crate / lockbox textures)
	{ name = "Battered Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Tattered Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Large Battered Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Solid Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Large Solid Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_03" },
	{ name = "Alliance Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Horde Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Treasure Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Buried Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Battered Footlocker", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Waterlogged Footlocker", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Dented Footlocker", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_01" },
	{ name = "Large Iron Bound Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Large Mithril Bound Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_04" },
	{ name = "Bound Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_02" },
	{ name = "Ornate Chest", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Box_03" },
	{ name = "Giant Clam", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_Shell_03" },
	{ name = "Practice Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Ornate Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Heavy Bronze Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Iron Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Strong Iron Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Steel Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Reinforced Steel Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Mithril Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Thorium Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
	{ name = "Eternium Lockbox", kind = KIND_CHEST, texture = "Interface\\Icons\\INV_Misc_OrnateBox" },
}

local byName = {}
for i = 1, #catalog do
	local entry = catalog[i]
	byName[string.lower(entry.name)] = entry
end

function ns.GetNodeInfo(name)
	if not name then
		return nil
	end
	return byName[string.lower(name)]
end

function ns.GetNodeSkill(name)
	local info = ns.GetNodeInfo(name)
	if not info then
		return nil
	end
	return info.skill, info.skillName
end

function ns.DefaultIcon(kind)
	return ns.DEFAULT_ICONS[kind] or ns.DEFAULT_ICONS[KIND_CHEST]
end

function ns.GetNodeIcon(name, kind)
	local info = ns.GetNodeInfo(name)
	if info then
		if info.itemID then
			local icon = ns.ItemIcon(info.itemID)
			if icon and icon ~= 0 then
				return icon
			end
		end
		if info.texture then
			return info.texture
		end
		kind = info.kind or kind
	end
	return ns.DefaultIcon(kind)
end

function ns.GuessKindFromName(name)
	local info = ns.GetNodeInfo(name)
	if info then
		return info.kind, info
	end
	if not name then
		return nil
	end
	local lower = string.lower(name)
	if string.find(lower, "chest", 1, true)
		or string.find(lower, "footlocker", 1, true)
		or string.find(lower, "lockbox", 1, true)
		or string.find(lower, "clam", 1, true) then
		return KIND_CHEST
	end
	if string.find(lower, "vein", 1, true) or string.find(lower, "deposit", 1, true) then
		return KIND_ORE
	end
	return nil
end
