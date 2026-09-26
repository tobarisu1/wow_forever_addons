local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cffffcc66Backend|r"

-- Public table other addons call. Frozen after the methods below exist.
Backend = {}

local ready = false
local callbacks = {
	Ready = {},
	BagCacheUpdate = {},
}

local function Print(message)
	print(ns.PREFIX .. ": " .. message)
end

local function IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
end

local function PlainString(value)
	if type(value) ~= "string" or value == "" or IsSecret(value) then
		return nil
	end
	return value
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

local function Fire(event, ...)
	local list = callbacks[event]
	if not list then
		return
	end
	for i = 1, #list do
		pcall(list[i], event, ...)
	end
end

ns.Fire = Fire

function ns.InitDB()
	if type(BackendDB) ~= "table" then
		BackendDB = {}
	end
	if type(BackendDB.version) ~= "number" then
		BackendDB.version = 1
	end
	if type(BackendDB.characters) ~= "table" then
		BackendDB.characters = {}
	end
end

local function RuleActive(ruleName)
	local rules = Enum and Enum.GameRule
	local rule = rules and rules[ruleName]
	if not rule or not C_GameRules or not C_GameRules.IsGameRuleActive then
		return false
	end
	local ok, active = pcall(C_GameRules.IsGameRuleActive, rule)
	return ok and active and true or false
end

-- Forever has no realms. Ruleset is the stand-in. Normalized realm is only valid after login.
local function RealmKey()
	local rules = Enum and Enum.GameRule
	local hasRuleset = rules and (rules.HardcoreRuleset or rules.RPRuleset or rules.PvPRuleset or rules.PvERuleset)
	if hasRuleset then
		if RuleActive("HardcoreRuleset") then
			return "Hardcore"
		end
		if RuleActive("RPRuleset") then
			return "RP"
		end
		if RuleActive("PvPRuleset") then
			return "PvP"
		end
		return "PvE"
	end

	local build
	if GetBuildInfo then
		local ok, _, _, _, version = pcall(GetBuildInfo)
		if ok then
			build = PlainNumber(version)
		end
	end
	if build and build > 16000 and build < 20000 then
		return "PvE"
	end

	if GetNormalizedRealmName then
		local ok, realm = pcall(GetNormalizedRealmName)
		if ok then
			realm = PlainString(realm)
			if realm then
				return realm
			end
		end
	end
	return "PvE"
end

local function CharacterName()
	if not UnitName then
		return nil
	end
	local ok, name = pcall(UnitName, "player")
	if not ok then
		return nil
	end
	name = PlainString(name)
	if not name then
		return nil
	end
	local shortName = string.match(name, "^([^%-]+)")
	if shortName and shortName ~= "" then
		return shortName
	end
	return name
end

local function UpdateMoney(row)
	if not row or not GetMoney then
		return
	end
	local ok, money = pcall(GetMoney)
	if not ok then
		return
	end
	money = PlainNumber(money)
	if money then
		row.money = money
	elseif type(row.money) ~= "number" then
		row.money = 0
	end
end

local function EnsureCharacter()
	local name = CharacterName()
	if not name then
		return nil
	end
	local realm = RealmKey()
	local fullName = name .. "-" .. realm
	local characters = BackendDB.characters
	local row = characters[fullName]
	if type(row) ~= "table" then
		row = {
			bags = {},
			bank = {},
			money = 0,
			details = {},
		}
		characters[fullName] = row
	end
	if type(row.bags) ~= "table" then
		row.bags = {}
	end
	if type(row.bank) ~= "table" then
		row.bank = {}
	end
	if type(row.details) ~= "table" then
		row.details = {}
	end

	row.details.character = name
	row.details.realm = realm
	if UnitClass then
		local ok, _, classFile = pcall(UnitClass, "player")
		if ok then
			local className = PlainString(classFile)
			if className then
				row.details.class = className
			end
		end
	end
	if UnitFactionGroup then
		local ok, faction = pcall(UnitFactionGroup, "player")
		if ok then
			faction = PlainString(faction)
			if faction then
				row.details.faction = faction
			end
		end
	end
	UpdateMoney(row)

	ns.currentCharacter = fullName
	return fullName
end

function ns.CurrentRow()
	if not ns.currentCharacter or type(BackendDB) ~= "table" or type(BackendDB.characters) ~= "table" then
		return nil
	end
	return BackendDB.characters[ns.currentCharacter]
end

function Backend.IsReady()
	return ready
end

function Backend.GetCurrentCharacter()
	return ns.currentCharacter
end

function Backend.GetCharacter(fullName)
	if type(fullName) ~= "string" or type(BackendDB) ~= "table" or type(BackendDB.characters) ~= "table" then
		return nil
	end
	local row = BackendDB.characters[fullName]
	if type(row) ~= "table" then
		return nil
	end
	return row
end

function Backend.GetAllCharacters()
	local names = {}
	if type(BackendDB) ~= "table" or type(BackendDB.characters) ~= "table" then
		return names
	end
	for fullName in pairs(BackendDB.characters) do
		if type(fullName) == "string" then
			names[#names + 1] = fullName
		end
	end
	table.sort(names)
	return names
end

function Backend.IsBagEventPending()
	if ns.BagEventPending then
		return ns.BagEventPending()
	end
	return false
end

function Backend.RegisterCallback(event, callback)
	local list = callbacks[event]
	if not list or type(callback) ~= "function" then
		return
	end
	list[#list + 1] = callback
	if event == "Ready" and ready then
		pcall(callback, "Ready")
	end
end

local function CountItems(container)
	local count = 0
	if type(container) ~= "table" then
		return 0
	end
	for _, slots in pairs(container) do
		if type(slots) == "table" then
			for _, slot in pairs(slots) do
				if type(slot) == "table" and type(slot.itemID) == "number" then
					count = count + 1
				end
			end
		end
	end
	return count
end

local function MoneyText(copper)
	copper = PlainNumber(copper) or 0
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local rest = copper % 100
	return gold .. "g " .. silver .. "s " .. rest .. "c"
end

local function PrintStatus()
	if not ready then
		Print("not ready")
		return
	end
	local fullName = ns.currentCharacter or "unknown"
	local row = Backend.GetCharacter(fullName)
	local state = "idle"
	if Backend.IsBagEventPending() then
		state = "updating"
	end
	local bagItems = 0
	local bankItems = 0
	local money = 0
	if row then
		bagItems = CountItems(row.bags)
		bankItems = CountItems(row.bank)
		money = row.money
	end
	Print(fullName)
	print("Cache: " .. state .. "  bag items " .. bagItems .. "  bank items " .. bankItems)
	print("Characters: " .. #Backend.GetAllCharacters() .. "  money " .. MoneyText(money))
end

local function PrintMenu()
	Print("/be status")
	PrintStatus()
end

local function HandleSlash(message)
	message = string.lower(string.match(message or "", "^%s*(.-)%s*$") or "")
	if message == "" or message == "status" then
		PrintStatus()
		return
	end
	PrintMenu()
end

local function OnLogin()
	ns.InitDB()
	if not EnsureCharacter() then
		Print("loaded, but the character name was not ready. Type /be for status.")
		return
	end
	if ns.StartCache then
		ns.StartCache()
	end
	if not ready then
		ready = true
		Fire("Ready")
	end
	Print("loaded. Type /be for the menu.")
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		OnLogin()
	elseif event == "PLAYER_MONEY" then
		UpdateMoney(ns.CurrentRow())
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_MONEY")

SLASH_BACKEND1 = "/be"
SLASH_BACKEND2 = "/backend"
SlashCmdList["BACKEND"] = HandleSlash

if table.freeze then
	pcall(table.freeze, Backend)
end
