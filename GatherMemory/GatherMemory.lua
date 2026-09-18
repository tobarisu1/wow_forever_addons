local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cff33cc99GatherMemory|r"
ns.MINIMAP_PIN_SIZE = 14
ns.WORLDMAP_PIN_SIZE = 12
ns.DEDUP_YARDS = 20
ns.DEDUP_MAP = 0.005

local defaults = {
	version = 1,
	settings = {
		showMinimap = true,
		showWorldMap = true,
		showHerbs = true,
		showOre = true,
		showChests = true,
	},
	nodes = {},
}

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

function ns.InitDB()
	if type(GatherMemoryDB) ~= "table" then
		GatherMemoryDB = {}
	end
	CopyDefaults(defaults, GatherMemoryDB)
end

function ns.GetSetting(key)
	return GatherMemoryDB.settings[key]
end

function ns.SetSetting(key, value)
	GatherMemoryDB.settings[key] = value
	ns.RefreshAll()
end

function ns.IsKindShown(kind)
	if kind == "herb" then
		return ns.GetSetting("showHerbs")
	end
	if kind == "ore" then
		return ns.GetSetting("showOre")
	end
	if kind == "chest" then
		return ns.GetSetting("showChests")
	end
	return false
end

function ns.KindLabel(kind)
	if kind == "herb" then
		return "Herb"
	end
	if kind == "ore" then
		return "Ore"
	end
	if kind == "chest" then
		return "Chest"
	end
	return kind or "Unknown"
end

local function MapKey(uiMapID)
	return tonumber(uiMapID) or uiMapID
end

function ns.GetNodeList(uiMapID)
	if not GatherMemoryDB or not GatherMemoryDB.nodes then
		return nil
	end
	local key = MapKey(uiMapID)
	return GatherMemoryDB.nodes[key] or GatherMemoryDB.nodes[tostring(uiMapID)]
end

function ns.GetOrCreateNodeList(uiMapID)
	local key = MapKey(uiMapID)
	local list = ns.GetNodeList(key)
	if not list then
		list = {}
		GatherMemoryDB.nodes[key] = list
	end
	return list
end

function ns.CountNodes(uiMapID)
	if uiMapID then
		local list = ns.GetNodeList(uiMapID)
		if not list then
			return 0
		end
		return #list
	end
	local total = 0
	for _, list in pairs(GatherMemoryDB.nodes) do
		total = total + #list
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

function ns.GetPlayerLocation()
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
	local x, y
	if pos.GetXY then
		x, y = pos:GetXY()
	else
		x, y = pos.x, pos.y
	end
	if not x or not y then
		return nil
	end
	local wy, wx, _, instance = UnitPosition("player")
	if (not wx or not wy) and C_Map.GetWorldPosFromMapPos then
		local continentID, worldPos = C_Map.GetWorldPosFromMapPos(uiMapID, pos)
		if worldPos then
			if worldPos.GetXY then
				wx, wy = worldPos:GetXY()
			else
				wx, wy = worldPos.x, worldPos.y
			end
			instance = continentID
		end
	end
	return {
		uiMapID = uiMapID,
		x = x,
		y = y,
		wx = wx,
		wy = wy,
		instance = instance,
	}
end

local function DistanceYards(a, b)
	if a.wx and b.wx and a.wy and b.wy then
		if a.instance ~= nil and b.instance ~= nil and a.instance ~= b.instance then
			return nil
		end
		local dx = a.wx - b.wx
		local dy = a.wy - b.wy
		return math.sqrt(dx * dx + dy * dy)
	end
	return nil
end

local function IsDuplicate(existing, loc, name, kind)
	if existing.name ~= name or existing.kind ~= kind then
		return false
	end
	local yards = DistanceYards(existing, loc)
	if yards then
		return yards <= ns.DEDUP_YARDS
	end
	local dx = (existing.x or 0) - (loc.x or 0)
	local dy = (existing.y or 0) - (loc.y or 0)
	return (dx * dx + dy * dy) <= (ns.DEDUP_MAP * ns.DEDUP_MAP)
end

function ns.AddNode(name, kind)
	if not name or name == "" or not kind then
		return false, false
	end
	local loc = ns.GetPlayerLocation()
	if not loc then
		return false, false
	end
	local list = ns.GetOrCreateNodeList(loc.uiMapID)
	for i = 1, #list do
		local existing = list[i]
		if IsDuplicate(existing, loc, name, kind) then
			existing.x = loc.x
			existing.y = loc.y
			existing.wx = loc.wx
			existing.wy = loc.wy
			existing.instance = loc.instance
			existing.lastSeen = time()
			ns.RefreshAll()
			return true, false
		end
	end
	list[#list + 1] = {
		x = loc.x,
		y = loc.y,
		wx = loc.wx,
		wy = loc.wy,
		instance = loc.instance,
		kind = kind,
		name = name,
		lastSeen = time(),
	}
	if ns.CountNodes() == 1 then
		ns.Print("Saved " .. name .. ". Type /gm for options.")
	end
	ns.RefreshAll()
	return true, true
end

function ns.ClearZone(uiMapID)
	uiMapID = uiMapID or (ns.GetPlayerLocation() and ns.GetPlayerLocation().uiMapID)
	if not uiMapID then
		return 0
	end
	local removed = ns.CountNodes(uiMapID)
	GatherMemoryDB.nodes[MapKey(uiMapID)] = nil
	GatherMemoryDB.nodes[tostring(uiMapID)] = nil
	ns.RefreshAll()
	return removed
end

function ns.ClearAll()
	local removed = ns.CountNodes()
	GatherMemoryDB.nodes = {}
	ns.RefreshAll()
	return removed
end

function ns.PruneNonTreasureNodes()
	if not GatherMemoryDB or not GatherMemoryDB.nodes then
		return 0
	end
	local removed = 0
	for uiMapID, list in pairs(GatherMemoryDB.nodes) do
		local keep = {}
		for i = 1, #list do
			local node = list[i]
			if node.kind == "chest" and ns.GuessKindFromName(node.name) ~= "chest" then
				removed = removed + 1
			else
				keep[#keep + 1] = node
			end
		end
		if #keep == 0 then
			GatherMemoryDB.nodes[uiMapID] = nil
		else
			GatherMemoryDB.nodes[uiMapID] = keep
		end
	end
	return removed
end

function ns.ForEachNode(callback)
	if not GatherMemoryDB or not GatherMemoryDB.nodes then
		return
	end
	for uiMapID, list in pairs(GatherMemoryDB.nodes) do
		for i = 1, #list do
			callback(list[i], uiMapID)
		end
	end
end

local function FormatLastSeen(timestamp)
	if not timestamp or timestamp == 0 then
		return "Last seen: unknown"
	end
	local now = time()
	local day = 24 * 60 * 60
	local diff = now - timestamp
	if diff < day and date("%Y%m%d", now) == date("%Y%m%d", timestamp) then
		return "Last seen: today"
	end
	if diff < (2 * day) then
		return "Last seen: yesterday"
	end
	return "Last seen: " .. date("%b %d, %Y", timestamp)
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
	GameTooltip:AddLine(FormatLastSeen(node.lastSeen), 0.75, 0.75, 0.75)
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
	ns.Print("minimap " .. BoolText(ns.GetSetting("showMinimap"))
		.. "  worldmap " .. BoolText(ns.GetSetting("showWorldMap"))
		.. "  herbs " .. BoolText(ns.GetSetting("showHerbs"))
		.. "  ore " .. BoolText(ns.GetSetting("showOre"))
		.. "  chests " .. BoolText(ns.GetSetting("showChests")))
	print("Nodes saved: " .. ns.CountNodes())
end

local function PrintMenu()
	ns.Print("/gm herbs | ore | chests | minimap | worldmap on | off")
	print("/gm status")
	print("/gm clear zone | all")
	PrintStatus()
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

local settingNames = {
	herbs = "showHerbs",
	ore = "showOre",
	chests = "showChests",
	minimap = "showMinimap",
	worldmap = "showWorldMap",
}

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
	local setting = settingNames[cmd]
	local value = ParseOnOff(rest)
	if setting and value ~= nil then
		ns.SetSetting(setting, value)
		ns.Print(cmd .. " " .. BoolText(value))
		return
	end
	PrintMenu()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedName)
	if event == "ADDON_LOADED" and loadedName == addonName then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		ns.InitDB()
		local pruned = ns.PruneNonTreasureNodes()
		if ns.InitCollector then
			ns.InitCollector()
		end
		if ns.InitMinimap then
			ns.InitMinimap()
		end
		if ns.InitWorldMap then
			ns.InitWorldMap()
		end
		ns.Print("loaded. Type /gm for the menu.")
		if pruned > 0 then
			ns.Print("Removed " .. pruned .. " quest objects. Chests are still tracked.")
			ns.RefreshAll()
		end
	end
end)

SLASH_GATHERMEMORY1 = "/gm"
SLASH_GATHERMEMORY2 = "/gathermemory"
SlashCmdList["GATHERMEMORY"] = HandleSlash
