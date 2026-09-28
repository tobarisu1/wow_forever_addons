local _, ns = ...

local QUEST_ITEM_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem
local QUALITY_POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor
if QUALITY_POOR == nil then
	QUALITY_POOR = 0
end

local CLASS_LABEL = {}
local function MapClass(enumName, key, label)
	local classID = Enum and Enum.ItemClass and Enum.ItemClass[enumName]
	if classID then
		CLASS_LABEL[classID] = { key = key, label = label }
	end
end

MapClass("Consumable", "consumable", "Consumable")
MapClass("Weapon", "weapon", "Weapon")
MapClass("Armor", "armor", "Armor")
MapClass("Reagent", "reagent", "Reagent")
MapClass("Tradegoods", "tradegoods", "Trade Goods")
MapClass("Recipe", "recipe", "Recipe")
MapClass("Projectile", "projectile", "Projectile")
MapClass("Key", "key", "Key")

-- itemID -> { { profession, recipe, count }, ... }
local uses = {}

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
	if value == nil or IsSecret(value) then
		return false
	end
	return value and true or false
end

local function ItemQuality(itemID)
	if C_Item and C_Item.GetItemQualityByID then
		local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
		if ok then
			return PlainNumber(quality)
		end
	end
	return nil
end

local function ItemClassID(itemID)
	if not C_Item or not C_Item.GetItemInfoInstant then
		return nil
	end
	local results = { pcall(C_Item.GetItemInfoInstant, itemID) }
	if not results[1] then
		return nil
	end
	return PlainNumber(results[7])
end

local function IsCraftingReagent(itemID)
	if not C_Item or not C_Item.GetItemInfo then
		return false
	end
	local results = { pcall(C_Item.GetItemInfo, itemID) }
	if not results[1] then
		return false
	end
	return PlainBool(results[18])
end

function BackendMaster.DescribeItem(itemID)
	itemID = PlainNumber(itemID)
	if not itemID then
		return nil
	end
	if ItemQuality(itemID) == QUALITY_POOR then
		return { key = "junk", label = "Junk" }
	end
	local classID = ItemClassID(itemID)
	if classID ~= nil and QUEST_ITEM_CLASS ~= nil and classID == QUEST_ITEM_CLASS then
		return { key = "quest", label = "Quest" }
	end
	local described = CLASS_LABEL[classID]
	if described then
		return { key = described.key, label = described.label }
	end
	if classID == nil and ItemQuality(itemID) == nil then
		return nil
	end
	if IsCraftingReagent(itemID) then
		return { key = "reagent", label = "Reagent" }
	end
	return { key = "other", label = "Other" }
end

local function AddUse(itemID, profession, recipe, count)
	local list = uses[itemID]
	if not list then
		list = {}
		uses[itemID] = list
	end
	for i = 1, #list do
		local row = list[i]
		if row.profession == profession and row.recipe == recipe then
			if count > row.count then
				row.count = count
			end
			return
		end
	end
	list[#list + 1] = {
		profession = profession,
		recipe = recipe,
		count = count,
	}
end

local function IndexRecipe(recipeID, fallbackProfession)
	recipeID = PlainNumber(recipeID)
	if not recipeID or not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic then
		return
	end
	local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or type(schematic) ~= "table" then
		return
	end
	local recipe = PlainString(schematic.name)
	local slots = schematic.reagentSlotSchematics
	if not recipe or type(slots) ~= "table" then
		return
	end
	local profession = PlainString(fallbackProfession)
	if C_TradeSkillUI.GetProfessionInfoByRecipeID then
		local infoOk, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if infoOk and type(info) == "table" then
			profession = PlainString(info.professionName) or profession
		end
	end
	if not profession then
		profession = "Profession"
	end
	for i = 1, #slots do
		local slot = slots[i]
		if type(slot) == "table" and type(slot.reagents) == "table" then
			local count = PlainNumber(slot.quantityRequired)
			if not count or count < 1 then
				count = 1
			end
			for j = 1, #slot.reagents do
				local reagent = slot.reagents[j]
				local reagentID = type(reagent) == "table" and PlainNumber(reagent.itemID)
				if reagentID then
					AddUse(reagentID, profession, recipe, count)
				end
			end
		end
	end
end

local function IndexSpellList(spells, professionName)
	if type(spells) ~= "table" then
		return
	end
	for i = 1, #spells do
		IndexRecipe(spells[i], professionName)
	end
end

local function IndexKnownProfessions()
	if not C_TradeSkillUI or not C_TradeSkillUI.GetChildProfessionInfos or not C_TradeSkillUI.GetProfessionSpells then
		return
	end
	local ok, infos = pcall(C_TradeSkillUI.GetChildProfessionInfos)
	if not ok or type(infos) ~= "table" then
		return
	end
	for i = 1, #infos do
		local info = infos[i]
		if type(info) == "table" then
			local professionID = PlainNumber(info.professionID)
			if professionID then
				local spellsOk, spells = pcall(C_TradeSkillUI.GetProfessionSpells, professionID)
				if spellsOk then
					IndexSpellList(spells, info.professionName)
				end
			end
		end
	end
end

local function IndexOpenProfession()
	if not C_TradeSkillUI or not C_TradeSkillUI.GetFilteredRecipeIDs then
		return
	end
	local profession
	if C_TradeSkillUI.GetBaseProfessionInfo then
		local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
		if ok and type(info) == "table" then
			profession = info.professionName
		end
	end
	local ok, recipeIDs = pcall(C_TradeSkillUI.GetFilteredRecipeIDs)
	if not ok then
		return
	end
	IndexSpellList(recipeIDs, profession)
end

function BackendMaster.GetItemUses(itemID)
	itemID = PlainNumber(itemID)
	local list = itemID and uses[itemID]
	local copy = {}
	if type(list) ~= "table" then
		return copy
	end
	for i = 1, #list do
		copy[i] = list[i]
	end
	return copy
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		IndexKnownProfessions()
	elseif event == "TRADE_SKILL_LIST_UPDATE" then
		IndexOpenProfession()
	end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

if table.freeze then
	pcall(table.freeze, BackendMaster)
end
