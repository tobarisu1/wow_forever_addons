local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cff33cc99GatherMemory|r"
ns.MINIMAP_PIN_SIZE = 14
ns.WORLDMAP_PIN_SIZE = 12
ns.DEDUP_MAP = 0.005

ns.KINDS = {
	{ id = "herb", setting = "showHerbs", label = "Herb", commands = { "herbs", "herb", "herbalism" } },
	{ id = "ore", setting = "showOre", label = "Ore", commands = { "ore", "mining" } },
	{ id = "chest", setting = "showChests", label = "Chest", commands = { "chests", "chest", "treasure" } },
	{ id = "fish", setting = "showFish", label = "Fishing", commands = { "fish", "fishing" } },
}

ns.DISPLAYS = {
	{ setting = "showMinimap", command = "minimap" },
	{ setting = "showWorldMap", command = "worldmap" },
}

local kindById = {}
local settingByCommand = {}
local commandNames = {}

for i = 1, #ns.KINDS do
	local kind = ns.KINDS[i]
	kindById[kind.id] = kind
	commandNames[#commandNames + 1] = kind.commands[1]
	for j = 1, #kind.commands do
		settingByCommand[kind.commands[j]] = kind.setting
	end
end
for i = 1, #ns.DISPLAYS do
	local display = ns.DISPLAYS[i]
	commandNames[#commandNames + 1] = display.command
	settingByCommand[display.command] = display.setting
end

local defaults = {
	settings = {
		showMinimap = true,
		showWorldMap = true,
	},
}

for i = 1, #ns.KINDS do
	defaults.settings[ns.KINDS[i].setting] = true
end

function ns.Print(message)
	print(ns.PREFIX .. ": " .. message)
end

local function CopyDefaults(src, dest)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dest[key]) ~= "table" then
				dest[key] = {}
			end
			CopyDefaults(value, dest[key])
		elseif dest[key] == nil then
			dest[key] = value
		end
	end
end

local function IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
end

local function RevealText(value)
	if value == nil then
		return nil
	end
	if type(value) == "string" and not IsSecret(value) then
		if value == "" then
			return nil
		end
		return value
	end
	local ok, text = pcall(function()
		return value .. ""
	end)
	if not ok or type(text) ~= "string" then
		return nil
	end
	local empty = false
	pcall(function()
		empty = text == ""
	end)
	if empty or IsSecret(text) then
		return nil
	end
	return text
end

local function Unwrap(value)
	if value == nil then
		return nil
	end
	if secretunwrap then
		local ok, result = pcall(secretunwrap, value)
		if ok and result ~= nil then
			return result
		end
	end
	if not IsSecret(value) then
		return value
	end
	local text = RevealText(value)
	if text == nil then
		return nil
	end
	if text == "true" then
		return true
	end
	if text == "false" then
		return false
	end
	if type(value) == "number" then
		return tonumber(text)
	end
	return text
end

local function PublicNumber(value)
	if value == nil then
		return nil
	end
	local revealed = Unwrap(value)
	if type(revealed) == "number" then
		return revealed
	end
	return tonumber(revealed)
end

ns.PublicNumber = PublicNumber

local function PublicText(value)
	local text = RevealText(value)
	if not text or text == "" then
		return nil
	end
	return text
end

ns.PublicText = PublicText

local function PublicBool(value)
	if type(value) == "boolean" and not IsSecret(value) then
		return value
	end
	local text = RevealText(value)
	if text == "true" then
		return true
	end
	if text == "false" then
		return false
	end
	return nil
end

local function Grid(value)
	value = PublicNumber(value)
	if not value then
		return nil
	end
	if value < 0 then
		value = 0
	elseif value > 0.9999 then
		value = 0.9999
	end
	return math.floor(value * 10000 + 0.5)
end

local function EncodeLoc(x, y)
	local xi, yi = Grid(x), Grid(y)
	if not xi or not yi then
		return nil
	end
	return xi .. ":" .. yi
end

local function DecodeLoc(coord)
	if coord == nil then
		return nil
	end
	local text = PublicText(coord)
	if text then
		coord = text
	end
	if type(coord) == "string" then
		local xs, ys = string.match(coord, "^(%d+):(%d+)$")
		if xs and ys then
			return tonumber(xs) / 10000, tonumber(ys) / 10000
		end
		return nil
	end
	if type(coord) ~= "number" then
		return nil
	end
	return math.floor(coord / 1000000) / 10000, math.floor((coord % 1000000) / 100) / 10000
end

local function NormalizeCoord(coord)
	local x, y = DecodeLoc(coord)
	if not x or not y then
		return nil
	end
	return EncodeLoc(x, y)
end

local function ZoneKey(map)
	local id = PublicNumber(map) or tonumber(map)
	if not id then
		return nil
	end
	return tostring(id)
end

local function StoredName(value)
	if ns.GetNameForNode then
		local name = ns.GetNameForNode(value)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return PublicText(value)
end

local function SameMap(a, b)
	if a == nil or b == nil then
		return false
	end
	local na, nb = PublicNumber(a), PublicNumber(b)
	if na and nb then
		return na == nb
	end
	local ok, same = pcall(function()
		return a == b or tostring(a) == tostring(b)
	end)
	return ok and same
end

-- Nested SavedVariables keys come back unreadable on this client, so the file
-- stores one string (same as TobarisuMapDB.point). Pins are served from cache.
local cache = {}

local function CacheKey(kind, map, xy)
	return kind .. ":" .. map .. ":" .. xy
end

local function CacheHas(kind, map, xy, name, x, y)
	for i = 1, #cache do
		local node = cache[i]
		if node.kind == kind and node.name == name and SameMap(node.uiMapID, map) then
			local dx = node.x - x
			local dy = node.y - y
			if (dx * dx + dy * dy) <= (ns.DEDUP_MAP * ns.DEDUP_MAP) then
				return true
			end
		end
		if node.key == CacheKey(kind, map, xy) then
			return true
		end
	end
	return false
end

local function CacheAdd(kind, map, xy, name)
	kind = PublicText(kind) or kind
	local zone = ZoneKey(map)
	xy = NormalizeCoord(xy)
	name = StoredName(name)
	if not kindById[kind] or not zone or not xy or not name then
		return false
	end
	local x, y = DecodeLoc(xy)
	if not x or not y then
		return false
	end
	if CacheHas(kind, zone, xy, name, x, y) then
		return false
	end
	cache[#cache + 1] = {
		key = CacheKey(kind, zone, xy),
		kind = kind,
		uiMapID = tonumber(zone),
		x = x,
		y = y,
		xy = xy,
		name = name,
	}
	return true
end

local KIND_INDEX = { herb = 1, ore = 2, chest = 3, fish = 4 }
local INDEX_KIND = { "herb", "ore", "chest", "fish" }

local function FlushPacked()
	if type(GatherMemoryDB) ~= "table" then
		return
	end
	local oldCount = PublicNumber(GatherMemoryDB.count) or 0
	GatherMemoryDB.count = #cache
	for i = 1, #cache do
		local node = cache[i]
		local prefix = "n" .. i
		local xs, ys = string.match(node.xy, "^(%d+):(%d+)$")
		GatherMemoryDB[prefix .. "k"] = KIND_INDEX[node.kind]
		GatherMemoryDB[prefix .. "m"] = node.uiMapID
		GatherMemoryDB[prefix .. "x"] = tonumber(xs)
		GatherMemoryDB[prefix .. "y"] = tonumber(ys)
		GatherMemoryDB[prefix .. "i"] = (ns.GetIDForNode and ns.GetIDForNode(node.name)) or 0
	end
	for i = #cache + 1, oldCount do
		local prefix = "n" .. i
		GatherMemoryDB[prefix .. "k"] = nil
		GatherMemoryDB[prefix .. "m"] = nil
		GatherMemoryDB[prefix .. "x"] = nil
		GatherMemoryDB[prefix .. "y"] = nil
		GatherMemoryDB[prefix .. "i"] = nil
	end
	if #cache == 0 then
		return
	end
	local lines = {}
	for i = 1, #cache do
		local node = cache[i]
		lines[#lines + 1] = node.kind .. "|" .. tostring(node.uiMapID) .. "|" .. node.xy .. "|" .. node.name
	end
	GatherMemoryDB.packed = table.concat(lines, "\n")
end

local function RebuildFromRecords()
	if type(GatherMemoryDB) ~= "table" then
		return
	end
	local count = PublicNumber(GatherMemoryDB.count)
	if not count or count < 1 then
		return
	end
	for i = 1, count do
		local prefix = "n" .. i
		local kind = INDEX_KIND[PublicNumber(GatherMemoryDB[prefix .. "k"])]
		local map = PublicNumber(GatherMemoryDB[prefix .. "m"])
		local x = PublicNumber(GatherMemoryDB[prefix .. "x"])
		local y = PublicNumber(GatherMemoryDB[prefix .. "y"])
		local id = PublicNumber(GatherMemoryDB[prefix .. "i"])
		local name = (id and ns.GetNameForNode and ns.GetNameForNode(id)) or "Unknown node"
		if kind and map and x and y then
			CacheAdd(kind, map, tostring(x) .. ":" .. tostring(y), name)
		end
	end
end

local function RebuildFromPacked()
	if type(GatherMemoryDB) ~= "table" then
		return
	end
	local text = PublicText(GatherMemoryDB.packed)
	if not text then
		return
	end
	pcall(function()
		for rawLine in string.gmatch(text, "[^\n]+") do
			local line = string.gsub(rawLine, "\r", "")
			local kind, zone, coord, name = string.match(line, "^([^|]+)|([^|]+)|([^|]+)|(.+)$")
			if kind then
				CacheAdd(kind, zone, coord, name)
			end
		end
	end)
end

local function FlattenNestedNodes()
	if type(GatherMemoryDB) ~= "table" or type(GatherMemoryDB.nodes) ~= "table" then
		return
	end
	pcall(function()
		for kind, nodedb in pairs(GatherMemoryDB.nodes) do
			kind = PublicText(kind) or kind
			if kindById[kind] and type(nodedb) == "table" then
				for zone, coords in pairs(nodedb) do
					if type(coords) == "table" then
						for coord, nodeID in pairs(coords) do
							CacheAdd(kind, zone, coord, nodeID)
						end
					end
				end
			end
		end
	end)
	if type(GatherMemoryDB.list) == "table" then
		pcall(function()
			for _, row in pairs(GatherMemoryDB.list) do
				if type(row) == "table" then
					CacheAdd(row.kind, row.map, row.xy, row.name)
				end
			end
		end)
	end
end

local function LoadCache()
	RebuildFromRecords()
	RebuildFromPacked()
	FlattenNestedNodes()
	if #cache > 0 then
		FlushPacked()
	end
end

function ns.InitDB()
	if type(GatherMemoryDB) ~= "table" then
		GatherMemoryDB = {}
	end
	if type(GatherMemoryDB.settings) ~= "table" then
		GatherMemoryDB.settings = {}
	end
	CopyDefaults(defaults.settings, GatherMemoryDB.settings)
	LoadCache()
end

function ns.GetSetting(key)
	if type(GatherMemoryDB) ~= "table" or type(GatherMemoryDB.settings) ~= "table" then
		return nil
	end
	local value = GatherMemoryDB.settings[key]
	local flag = PublicBool(value)
	if flag ~= nil then
		return flag
	end
	return value
end

function ns.SetSetting(key, value)
	if type(GatherMemoryDB) ~= "table" then
		return
	end
	if type(GatherMemoryDB.settings) ~= "table" then
		GatherMemoryDB.settings = {}
	end
	GatherMemoryDB.settings[key] = value
	ns.RefreshAll()
end

function ns.IsKindShown(kind)
	local info = kindById[kind]
	if not info then
		return false
	end
	return ns.GetSetting(info.setting) ~= false
end

function ns.KindLabel(kind)
	local info = kindById[kind]
	if not info then
		return kind or "Unknown"
	end
	return info.label
end

function ns.ForEachNode(callback)
	for i = 1, #cache do
		callback(cache[i], cache[i].uiMapID)
	end
end

function ns.CountNodes(uiMapID)
	local total = 0
	for i = 1, #cache do
		if not uiMapID or SameMap(cache[i].uiMapID, uiMapID) then
			total = total + 1
		end
	end
	return total
end

function ns.SpellName(spellID)
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spellID)
	end
	if GetSpellInfo then
		return GetSpellInfo(spellID)
	end
	return nil
end

function ns.ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		return C_Item.GetItemIconByID(itemID)
	end
	if GetItemIcon then
		return GetItemIcon(itemID)
	end
	return nil
end

local function Vector2(x, y)
	if CreateVector2D then
		return CreateVector2D(x, y)
	end
	return { x = x, y = y }
end

local function VectorXY(vec)
	if not vec then
		return nil
	end
	if vec.GetXY then
		return vec:GetXY()
	end
	return vec.x, vec.y
end

function ns.GetPlayerLocation(reveal)
	if not C_Map or not C_Map.GetBestMapForUnit then
		return nil
	end
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if not uiMapID then
		return nil
	end
	local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
	if not pos then
		return nil
	end
	local x, y = VectorXY(pos)
	if not x or not y then
		return nil
	end
	if reveal then
		uiMapID = PublicNumber(uiMapID)
		x, y = PublicNumber(x), PublicNumber(y)
		if not uiMapID or not x or not y then
			return nil
		end
	end
	return {
		uiMapID = uiMapID,
		x = x,
		y = y,
	}
end

function ns.OffsetLocationForward(loc, yards)
	if not loc or not yards or not loc.x or not loc.y or not loc.uiMapID then
		return loc
	end
	local facing = PublicNumber(GetPlayerFacing())
	if not facing or not C_Map or not C_Map.GetMapWorldSize then
		return loc
	end
	local width, height = C_Map.GetMapWorldSize(loc.uiMapID)
	width, height = PublicNumber(width), PublicNumber(height)
	if not width or not height or width == 0 or height == 0 then
		return loc
	end
	loc.x = loc.x - math.sin(facing) * yards / width
	loc.y = loc.y - math.cos(facing) * yards / height
	return loc
end

function ns.GetNodeWorldPosition(node)
	if not node or not node.uiMapID or not node.x or not node.y or not C_Map or not C_Map.GetWorldPosFromMapPos then
		return nil
	end
	local wx, wy
	pcall(function()
		local _, worldPos = C_Map.GetWorldPosFromMapPos(node.uiMapID, Vector2(node.x, node.y))
		wx, wy = VectorXY(worldPos)
	end)
	return wx, wy
end

function ns.GetNodeMapPosition(node, targetMapID)
	if not node or not targetMapID then
		return nil
	end
	if SameMap(node.uiMapID, targetMapID) and node.x and node.y then
		return node.x, node.y
	end
	return nil
end

function ns.AddNode(name, kind)
	name = PublicText(name)
	kind = PublicText(kind)
	if not name or not kind or not kindById[kind] then
		return false, false
	end
	if type(GatherMemoryDB) ~= "table" then
		GatherMemoryDB = {}
	end
	local loc = ns.GetPlayerLocation(true)
	if not loc then
		return false, false
	end
	if kind == "fish" then
		loc = ns.OffsetLocationForward(loc, 15)
	end
	local coord = EncodeLoc(loc.x, loc.y)
	if not coord then
		ns.Print("Could not save " .. name .. " — position is not writable.")
		return false, false
	end
	local zone = ZoneKey(loc.uiMapID)
	if not zone then
		ns.Print("Could not save " .. name .. " — saved variables are not loaded.")
		return false, false
	end
	if not CacheAdd(kind, zone, coord, name) then
		return true, false
	end
	FlushPacked()
	ns.Print("Saved " .. name .. ".")
	ns.RefreshAll()
	return true, true
end

function ns.ClearZone(uiMapID)
	local zone = ZoneKey(uiMapID)
	if not zone then
		local loc = ns.GetPlayerLocation(true)
		zone = loc and ZoneKey(loc.uiMapID)
	end
	if not zone then
		return 0
	end
	local removed = 0
	for i = #cache, 1, -1 do
		if SameMap(cache[i].uiMapID, zone) then
			table.remove(cache, i)
			removed = removed + 1
		end
	end
	FlushPacked()
	ns.RefreshAll()
	return removed
end

function ns.ClearAll()
	local removed = #cache
	for i = #cache, 1, -1 do
		cache[i] = nil
	end
	FlushPacked()
	if type(GatherMemoryDB) == "table" then
		GatherMemoryDB.packed = ""
	end
	ns.RefreshAll()
	return removed
end

function ns.PruneNonTreasureNodes()
	local removed = 0
	for i = #cache, 1, -1 do
		if cache[i].kind == "chest" and ns.GuessKindFromName(cache[i].name) ~= "chest" then
			table.remove(cache, i)
			removed = removed + 1
		end
	end
	if removed > 0 then
		FlushPacked()
		ns.RefreshAll()
	end
	return removed
end

function ns.ShowNodeTooltip(owner, node)
	if not node then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(node.name or "Unknown node", 1, 1, 1)
	GameTooltip:AddLine(ns.KindLabel(node.kind), 0.65, 0.85, 0.55)
	local skill, skillName = ns.GetNodeSkill(node.name)
	if skill and skillName then
		GameTooltip:AddLine("Requires " .. skill .. " " .. skillName, 0.85, 0.75, 0.45)
	end
	GameTooltip:Show()
end

function ns.HideNodeTooltip()
	GameTooltip:Hide()
end

function ns.RefreshAll()
	if ns.UpdateMinimap then
		ns.UpdateMinimap(true)
	end
	if ns.RefreshWorldMap then
		ns.RefreshWorldMap()
	end
end

local function BoolText(value)
	if value then
		return "ON"
	end
	return "OFF"
end

local function PrintStatus()
	local parts = {}
	for i = 1, #ns.DISPLAYS do
		local display = ns.DISPLAYS[i]
		parts[#parts + 1] = display.command .. " " .. BoolText(ns.GetSetting(display.setting))
	end
	for i = 1, #ns.KINDS do
		local kind = ns.KINDS[i]
		parts[#parts + 1] = kind.commands[1] .. " " .. BoolText(ns.GetSetting(kind.setting))
	end
	ns.Print(table.concat(parts, "  "))
	print("Nodes saved: " .. ns.CountNodes())
end

local function PrintMenu()
	ns.Print("/gm " .. table.concat(commandNames, " | ") .. " on | off")
	print("/gm status")
	print("/gm clear zone | all")
	print("/gm prune")
	print("/gm debug | where")
	PrintStatus()
end

local function PrintDebug()
	ns.Print("saved variables: " .. type(GatherMemoryDB))
	print("Cached pins: " .. ns.CountNodes())
	print("Record count field: " .. tostring(type(GatherMemoryDB) == "table" and PublicNumber(GatherMemoryDB.count)))
	local packed = type(GatherMemoryDB) == "table" and GatherMemoryDB.packed
	local text = PublicText(packed)
	if text then
		print("Packed length: " .. #text)
	else
		print("Packed unread, type: " .. type(packed))
	end
end

local function ParseOnOff(text)
	if text == "on" then
		return true
	end
	if text == "off" then
		return false
	end
	return nil
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "" then
		PrintMenu()
		return
	end
	if msg == "status" then
		PrintStatus()
		return
	end
	if msg == "debug" then
		PrintDebug()
		return
	end
	if msg == "prune" then
		local removed = ns.PruneNonTreasureNodes()
		ns.Print("Removed " .. removed .. " chest records that are not treasure chests.")
		return
	end
	if msg == "where" then
		if ns.DescribeMinimap then
			ns.Print("minimap placement")
			ns.DescribeMinimap()
		else
			ns.Print("minimap display is not loaded.")
		end
		return
	end
	local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
	if cmd == "clear" then
		if rest == "all" then
			local removed = ns.ClearAll()
			ns.Print("Cleared " .. removed .. " nodes.")
		elseif rest == "zone" then
			local removed = ns.ClearZone()
			ns.Print("Cleared " .. removed .. " nodes in this zone.")
		else
			ns.Print("/gm clear zone | all")
		end
		return
	end
	local setting = settingByCommand[cmd]
	local value = ParseOnOff(rest)
	if setting and value ~= nil then
		ns.SetSetting(setting, value)
		ns.Print(cmd .. " " .. BoolText(value))
		return
	end
	if setting then
		ns.Print("/gm " .. cmd .. " on | off")
		print("Currently: " .. BoolText(ns.GetSetting(setting)))
		return
	end
	PrintMenu()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, loadedName)
	if event == "ADDON_LOADED" and loadedName == addonName then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		LoadCache()
		if ns.InitCollector then
			ns.InitCollector()
		end
		if ns.InitMinimap then
			ns.InitMinimap()
		end
		if ns.InitWorldMap then
			ns.InitWorldMap()
		end
		ns.Print("loaded. " .. ns.CountNodes() .. " nodes saved. Type /gm for the menu.")
		ns.RefreshAll()
	elseif event == "PLAYER_ENTERING_WORLD" then
		LoadCache()
		ns.RefreshAll()
		if C_Timer and C_Timer.After then
			C_Timer.After(1, function()
				LoadCache()
				ns.RefreshAll()
			end)
		end
	elseif event == "PLAYER_LOGOUT" then
		FlushPacked()
	end
end)

GatherMemory = ns

SLASH_GATHERMEMORY1 = "/gm"
SLASH_GATHERMEMORY2 = "/gathermemory"
SlashCmdList["GATHERMEMORY"] = HandleSlash
