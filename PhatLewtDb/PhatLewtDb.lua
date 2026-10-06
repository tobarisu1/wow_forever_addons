local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cffffcc66PhatLewt|r"
ns.FRAME_SCALE = 1
ns.BOSS_WINDOW = 45

local TAGS = {
	quest = true,
	crafting = true,
	equipment = true,
	junk = true,
}

function ns.Print(message)
	print(ns.PREFIX .. ": " .. message)
end

function ns.IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
end

function ns.PlainString(value)
	if type(value) ~= "string" or value == "" or ns.IsSecret(value) then
		return nil
	end
	return value
end

function ns.PlainNumber(value)
	if value == nil or ns.IsSecret(value) then
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

function ns.PlainBool(value)
	if type(value) ~= "boolean" or ns.IsSecret(value) then
		return nil
	end
	return value
end

function ns.PlainIcon(value)
	if value == nil or ns.IsSecret(value) then
		return nil
	end
	if type(value) == "number" then
		if value > 0 and value ~= 134400 then
			return value
		end
		return nil
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

function ns.InitDB()
	if type(PhatLewtDbDB) ~= "table" then
		PhatLewtDbDB = {}
	end
	if type(PhatLewtDbDB.version) ~= "number" then
		PhatLewtDbDB.version = 1
	end
	if type(PhatLewtDbDB.zones) ~= "table" then
		PhatLewtDbDB.zones = {}
	end
	if type(PhatLewtDbDB.tags) ~= "table" then
		PhatLewtDbDB.tags = {}
	end
	if type(PhatLewtDbDB.filters) ~= "table" then
		PhatLewtDbDB.filters = {}
	end
end

function ns.CurrentCharacter()
	if type(BackendMaster) ~= "table" or type(BackendMaster.GetCurrentCharacter) ~= "function" then
		return nil
	end
	if BackendMaster.IsReady and not BackendMaster.IsReady() then
		return nil
	end
	local name = BackendMaster.GetCurrentCharacter()
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

local function MapType(name)
	local types = Enum and Enum.UIMapType
	if types and types[name] ~= nil then
		return types[name]
	end
	if name == "Zone" then
		return 3
	elseif name == "Continent" then
		return 2
	elseif name == "World" then
		return 1
	elseif name == "Cosmic" then
		return 0
	end
	return nil
end

-- Best-map is often a cave or town. Walk up to the zone so the log matches the home grid.
local function ParentZone(mapID)
	if not mapID or not C_Map or not C_Map.GetMapInfo then
		return mapID, nil
	end
	local zoneType = MapType("Zone")
	local continentType = MapType("Continent")
	local worldType = MapType("World")
	local cosmicType = MapType("Cosmic")
	local guard = 0
	local firstID, firstName
	while mapID and guard < 8 do
		guard = guard + 1
		local ok, info = pcall(C_Map.GetMapInfo, mapID)
		if not ok or type(info) ~= "table" then
			break
		end
		local infoName = ns.PlainString(info.name)
		local mapType = ns.PlainNumber(info.mapType)
		local parent = ns.PlainNumber(info.parentMapID)
		if not firstID then
			firstID = mapID
			firstName = infoName
		end
		if mapType == zoneType then
			return mapID, infoName
		end
		if mapType == continentType or mapType == worldType or mapType == cosmicType then
			break
		end
		if not parent or parent == mapID then
			break
		end
		mapID = parent
	end
	return firstID, firstName
end

function ns.CurrentPlace()
	local kind = "world"
	local name
	local mapID
	local instanceID

	if IsInInstance and GetInstanceInfo then
		local ok, inside, instanceType = pcall(IsInInstance)
		inside = ok and ns.PlainBool(inside)
		instanceType = ok and ns.PlainString(instanceType)
		if inside and (instanceType == "party" or instanceType == "raid") then
			local results = { pcall(GetInstanceInfo) }
			local infoOK = results[1]
			if infoOK then
				name = ns.PlainString(results[2])
				instanceID = ns.PlainNumber(results[9])
				if instanceType == "raid" then
					kind = "raid"
				else
					kind = "dungeon"
				end
			end
		end
	end

	if kind == "world" then
		if C_Map and C_Map.GetBestMapForUnit then
			local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
			if ok then
				mapID = ns.PlainNumber(id)
			end
		end
		if mapID then
			local zoneID, zoneName = ParentZone(mapID)
			if zoneID then
				mapID = zoneID
			end
			if zoneName then
				name = zoneName
			end
		end
		if not name and GetZoneText then
			local ok, zone = pcall(GetZoneText)
			if ok then
				name = ns.PlainString(zone)
			end
		end
	end

	if not name or name == "" then
		name = "Unknown"
	end

	local key
	if kind ~= "world" then
		if instanceID then
			key = "inst:" .. instanceID
		else
			key = "inst:" .. string.lower(name)
		end
	elseif mapID then
		key = "map:" .. mapID
	else
		key = "name:" .. string.lower(name)
	end

	return {
		key = key,
		name = name,
		kind = kind,
		mapID = mapID,
		instanceID = instanceID,
	}
end

function ns.GetTag(itemID)
	itemID = ns.PlainNumber(itemID)
	if not itemID or type(PhatLewtDbDB) ~= "table" or type(PhatLewtDbDB.tags) ~= "table" then
		return nil
	end
	local tag = PhatLewtDbDB.tags[itemID]
	if type(tag) ~= "string" then
		tag = PhatLewtDbDB.tags[tostring(itemID)]
	end
	if TAGS[tag] then
		return tag
	end
	return nil
end

function ns.SetTag(itemID, tag)
	ns.InitDB()
	itemID = ns.PlainNumber(itemID)
	if not itemID then
		return
	end
	if tag ~= nil and not TAGS[tag] then
		return
	end
	PhatLewtDbDB.tags[tostring(itemID)] = nil
	PhatLewtDbDB.tags[itemID] = tag
	if ns.RefreshList then
		ns.RefreshList()
	end
end

function ns.Counts()
	local zones, mobs, drops = 0, 0, 0
	if type(PhatLewtDbDB) ~= "table" or type(PhatLewtDbDB.zones) ~= "table" then
		return zones, mobs, drops
	end
	for _, zone in pairs(PhatLewtDbDB.zones) do
		if type(zone) == "table" then
			zones = zones + 1
			if type(zone.mobs) == "table" then
				for _, mob in pairs(zone.mobs) do
					if type(mob) == "table" then
						mobs = mobs + 1
						if type(mob.items) == "table" then
							for _, item in pairs(mob.items) do
								if type(item) == "table" then
									drops = drops + 1
								end
							end
						end
					end
				end
			end
		end
	end
	return zones, mobs, drops
end

function ns.QualityColor(quality)
	quality = ns.PlainNumber(quality)
	local colors = ITEM_QUALITY_COLORS
	local entry = colors and quality and colors[quality]
	if type(entry) == "table" then
		if type(entry.r) == "number" then
			return entry.r, entry.g, entry.b
		end
		if entry.color and entry.color.GetRGB then
			local ok, r, g, b = pcall(entry.color.GetRGB, entry.color)
			if ok and type(r) == "number" then
				return r, g, b
			end
		end
	end
	if quality == 4 then
		return 0.64, 0.21, 0.93
	elseif quality == 3 then
		return 0, 0.44, 0.87
	elseif quality == 2 then
		return 0.12, 1, 0
	elseif quality == 0 then
		return 0.62, 0.62, 0.62
	end
	return 1, 1, 1
end

local function PrintStatus()
	local zones, mobs, drops = ns.Counts()
	ns.Print("Zones: " .. zones .. "  Mobs: " .. mobs .. "  Items: " .. drops)
end

local function PrintMenu()
	ns.Print("/pld status")
	print("/pld clear zone | all")
	print("Right-click an item to tag it.")
	PrintStatus()
end

local function ClearZone()
	local place = ns.CurrentPlace()
	if not place then
		ns.Print("No zone to clear.")
		return
	end
	if type(PhatLewtDbDB.zones[place.key]) == "table" then
		PhatLewtDbDB.zones[place.key] = nil
		ns.Print("Cleared " .. place.name .. ".")
	else
		ns.Print("No drops saved for " .. place.name .. ".")
	end
	if ns.RefreshList then
		ns.RefreshList()
	end
end

local function ClearAll()
	PhatLewtDbDB.zones = {}
	ns.Print("Cleared every drop.")
	if ns.RefreshList then
		ns.RefreshList()
	end
end

local function HandleSlash(message)
	message = string.lower(string.match(message or "", "^%s*(.-)%s*$") or "")
	if message == "" then
		PrintMenu()
		if ns.ToggleWindow then
			ns.ToggleWindow()
		end
		return
	end
	if message == "status" then
		PrintStatus()
		return
	end
	local cmd, rest = string.match(message, "^(%S+)%s*(.-)$")
	if cmd == "clear" then
		if rest == "all" then
			ClearAll()
		elseif rest == "zone" then
			ClearZone()
		else
			ns.Print("/pld clear zone | all")
		end
		return
	end
	PrintMenu()
end

local function OnLogin()
	ns.InitDB()
	if ns.InitRecord then
		ns.InitRecord()
	end
	if ns.InitUI then
		ns.InitUI()
	end
	if type(BackendMaster) == "table" and type(BackendMaster.RegisterCallback) == "function" then
		BackendMaster.RegisterCallback("Ready", function()
			if ns.AttachCharacter then
				ns.AttachCharacter()
			end
		end)
	end
	local _, _, drops = ns.Counts()
	ns.Print("loaded. " .. drops .. " items saved. Type /pld for the menu.")
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		ns.InitDB()
	elseif event == "ADDON_LOADED" and name == "TobarisuMap" then
		if ns.DockMinimapButton then
			ns.DockMinimapButton()
		end
	elseif event == "PLAYER_LOGIN" then
		OnLogin()
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_PHATLEWTDB1 = "/pld"
SLASH_PHATLEWTDB2 = "/phatlewt"
SlashCmdList["PHATLEWTDB"] = HandleSlash
