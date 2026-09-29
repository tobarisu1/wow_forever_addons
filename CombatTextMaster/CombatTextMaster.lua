local addonName, ns = ...

ns.PREFIX = "|cffffcc66CombatTextMaster|r"

ns.FACES = {
	{ key = "friz", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ key = "arial", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ key = "morpheus", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ key = "skurri", label = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

ns.OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }

-- For now: rogue, warrior, priest, and shaman only.
-- Reactive rows are abilities the game announces when they become usable.
-- Cooldown rows are short cooldowns this addon watches itself.
-- spellIDs are vanilla ranks, lowest to highest. The known rank is the one watched.
ns.ALERTS = {
	{
		id = "riposte",
		class = "Rogue",
		name = "Riposte",
		spellIDs = { 14251 },
		kind = "reactive",
		blurb = "After you parry",
		detail = "The game announces this when Riposte is ready.",
	},
	{
		id = "kick",
		class = "Rogue",
		name = "Kick",
		spellIDs = { 1766, 1767, 1768, 1769 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Kick is ready again.",
	},
	{
		id = "ghostly",
		class = "Rogue",
		name = "Ghostly Strike",
		spellIDs = { 14278 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Ghostly Strike is ready again.",
	},
	{
		id = "kidney",
		class = "Rogue",
		name = "Kidney Shot",
		spellIDs = { 408, 8643 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Kidney Shot is ready again.",
	},
	{
		id = "overpower",
		class = "Warrior",
		name = "Overpower",
		spellIDs = { 7384, 7887, 11584, 11585 },
		kind = "reactive",
		blurb = "After a dodge",
		detail = "The game announces this when Overpower is ready.",
	},
	{
		id = "revenge",
		class = "Warrior",
		name = "Revenge",
		spellIDs = { 6572, 6574, 7379, 11600, 11601, 25288 },
		kind = "reactive",
		blurb = "After a block, dodge, or parry",
		detail = "The game announces this when Revenge is ready.",
	},
	{
		id = "mortalstrike",
		class = "Warrior",
		name = "Mortal Strike",
		spellIDs = { 12294, 21551, 21552, 21553, 25248 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Mortal Strike is ready again.",
	},
	{
		id = "bloodthirst",
		class = "Warrior",
		name = "Bloodthirst",
		spellIDs = { 23881, 23892, 23893, 23894, 25251 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Bloodthirst is ready again.",
	},
	{
		id = "shieldslam",
		class = "Warrior",
		name = "Shield Slam",
		spellIDs = { 23922, 23923, 23924, 23925, 25258 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Shield Slam is ready again.",
	},
	{
		id = "whirlwind",
		class = "Warrior",
		name = "Whirlwind",
		spellIDs = { 1680 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Whirlwind is ready again.",
	},
	{
		id = "mindblast",
		class = "Priest",
		name = "Mind Blast",
		spellIDs = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Mind Blast is ready again.",
	},
	{
		id = "holyfire",
		class = "Priest",
		name = "Holy Fire",
		spellIDs = { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Holy Fire is ready again.",
	},
	{
		id = "shield",
		class = "Priest",
		name = "Power Word: Shield",
		spellIDs = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Power Word: Shield is ready again.",
	},
	{
		id = "stormstrike",
		class = "Shaman",
		name = "Stormstrike",
		spellIDs = { 17364 },
		kind = "cooldown",
		blurb = "Short cooldown",
		detail = "Shows when Stormstrike is ready again.",
	},
	{
		id = "earthshock",
		class = "Shaman",
		name = "Earth Shock",
		spellIDs = { 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454 },
		kind = "cooldown",
		blurb = "Shared shock cooldown",
		detail = "Earth Shock, Flame Shock, and Frost Shock share this. Shows when that cooldown is ready again.",
	},
}

local DAMAGE_TYPES = {
	DAMAGE = { color = "damage" },
	DAMAGE_CRIT = { color = "damage", crit = true },
	SPELL_DAMAGE = { color = "spell" },
	SPELL_DAMAGE_CRIT = { color = "spell", crit = true },
	DAMAGE_SHIELD = { color = "spell" },
}

local COLORS = {
	damage = { 1, 0.1, 0.1 },
	spell = { 0.79, 0.3, 0.85 },
	alert = { 1, 0.82, 0 },
}

local REPEAT_WINDOW = 0.75
local recentAlerts = {}
local feedCarriesHits = false
local outgoingHintShown = false
local feedHintShown = false

local function Print(message)
	print(ns.PREFIX .. ": " .. message)
end
ns.Print = Print

function ns.IsSecret(value)
	if value == nil then
		return false
	end
	if issecretvalue then
		local ok, secret = pcall(issecretvalue, value)
		if ok then
			return secret and true or false
		end
		return true
	end
	return not pcall(tostring, value)
end

function ns.Readable(value)
	if value == nil or ns.IsSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if ok then
		return number
	end
	return nil
end

function ns.ReadableString(value)
	if type(value) ~= "string" or value == "" or ns.IsSecret(value) then
		return nil
	end
	return value
end

function ns.FaceByKey(key)
	for i = 1, #ns.FACES do
		if ns.FACES[i].key == key then
			return ns.FACES[i]
		end
	end
	return ns.FACES[1]
end

function ns.FaceLabel()
	return ns.FaceByKey(CombatTextMasterDB and CombatTextMasterDB.fontFace).label
end

function ns.FontFile()
	return ns.FaceByKey(CombatTextMasterDB and CombatTextMasterDB.fontFace).path
end

function ns.FontFlags()
	local outline = CombatTextMasterDB and CombatTextMasterDB.outline
	if outline == "OUTLINE" or outline == "THICKOUTLINE" then
		return outline
	end
	return ""
end

function ns.FontSize(large)
	local size = 18
	if CombatTextMasterDB and type(CombatTextMasterDB.fontSize) == "number" then
		size = CombatTextMasterDB.fontSize
	end
	if large then
		return size + 8
	end
	return size
end

local function KnownFace(key)
	for i = 1, #ns.FACES do
		if ns.FACES[i].key == key then
			return true
		end
	end
	return false
end

local function KnownOutline(outline)
	for i = 1, #ns.OUTLINES do
		if ns.OUTLINES[i] == outline then
			return true
		end
	end
	return false
end

function ns.InitDB()
	if type(CombatTextMasterDB) ~= "table" then
		CombatTextMasterDB = {}
	end
	local db = CombatTextMasterDB
	if db.enabled == nil then
		db.enabled = true
	end
	if not KnownFace(db.fontFace) then
		db.fontFace = "friz"
	end
	if type(db.fontSize) ~= "number" then
		db.fontSize = 18
	end
	if db.fontSize < 12 then
		db.fontSize = 12
	end
	if db.fontSize > 32 then
		db.fontSize = 32
	end
	if not KnownOutline(db.outline) then
		db.outline = "OUTLINE"
	end
	if type(db.alerts) ~= "table" then
		db.alerts = {}
	end
end

function ns.AlertByID(id)
	for i = 1, #ns.ALERTS do
		if ns.ALERTS[i].id == id then
			return ns.ALERTS[i]
		end
	end
	return nil
end

function ns.AlertEnabled(id)
	local alerts = CombatTextMasterDB and CombatTextMasterDB.alerts
	if type(alerts) ~= "table" or alerts[id] == nil then
		return true
	end
	return alerts[id] and true or false
end

function ns.SetAlertEnabled(id, on)
	ns.InitDB()
	CombatTextMasterDB.alerts[id] = on and true or false
end

function ns.SpellIDs(alert)
	if type(alert.spellIDs) == "table" then
		return alert.spellIDs
	end
	return { alert.spellID }
end

function ns.SpellKnown(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
		if ok then
			return known and true or false
		end
	end
	return nil
end

function ns.KnownSpellID(alert)
	local ids = ns.SpellIDs(alert)
	local found
	local unanswered = false
	for i = 1, #ids do
		local known = ns.SpellKnown(ids[i])
		if known == nil then
			unanswered = true
		elseif known then
			found = ids[i]
		end
	end
	if found then
		return found
	end
	if unanswered then
		return ids[1]
	end
	return nil
end

function ns.AlertName(alert)
	local spellID = ns.KnownSpellID(alert) or ns.SpellIDs(alert)[1]
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(name) == "string" and name ~= "" and not ns.IsSecret(name) then
			return name
		end
	end
	return alert.name
end

function ns.AlertIcon(alert)
	local spellID = ns.KnownSpellID(alert) or ns.SpellIDs(alert)[1]
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
		if ok and icon and not ns.IsSecret(icon) then
			return icon
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.AlertKnown(alert)
	return ns.KnownSpellID(alert) ~= nil
end

function ns.ReactiveByName(name)
	for i = 1, #ns.ALERTS do
		local alert = ns.ALERTS[i]
		if alert.kind == "reactive" and ns.AlertName(alert) == name then
			return alert
		end
	end
	return nil
end

local function StatusText()
	if CombatTextMasterDB.enabled then
		return "ON"
	end
	return "OFF"
end

local function PrintMenu()
	Print("/ctm on | off | status")
	Print("/ctm alerts")
	Print("/ctm opens the window")
	print("Currently: " .. StatusText() .. "  " .. ns.FaceLabel() .. " " .. tostring(ns.FontSize(false)) .. " " .. CombatTextMasterDB.outline)
end

local function CVarValue(name)
	if not GetCVar then
		return nil
	end
	local ok, value = pcall(GetCVar, name)
	if ok and value ~= nil then
		return tostring(value)
	end
	return nil
end

local function ResolveCVar(names)
	for i = 1, #names do
		local value = CVarValue(names[i])
		if value then
			return names[i], value
		end
	end
	return names[1], nil
end

local function EnsureCVar(names, turnedOn, refused)
	local name, value = ResolveCVar(names)
	if value == nil or value == "1" then
		return
	end
	if C_CVar and C_CVar.SetCVar then
		pcall(C_CVar.SetCVar, name, "1")
	end
	local _, after = ResolveCVar(names)
	if after == "1" then
		Print(turnedOn)
		return
	end
	Print(refused)
	print("  |cffffff00/console " .. name .. " 1|r")
end

function ns.EnsureOutgoing()
	if outgoingHintShown then
		return
	end
	local name, value = ResolveCVar({ "floatingCombatTextCombatDamage_v2", "floatingCombatTextCombatDamage" })
	if value == nil or value == "1" then
		return
	end
	outgoingHintShown = true
	EnsureCVar(
		{ name },
		"damage you deal is shown by the game over your target.",
		"damage you deal is drawn by the game over your target. That setting is off. Type:"
	)
end

local function EnsureFeed()
	if feedHintShown then
		return
	end
	local _, value = ResolveCVar({ "enableFloatingCombatText" })
	if value == nil or value == "1" then
		return
	end
	feedHintShown = true
	EnsureCVar(
		{ "enableFloatingCombatText" },
		"floating combat text was off. It is on now.",
		"the combat text feed is off. Type:"
	)
end

function ns.ClaimFeed()
	local api = C_CombatText
	if not (api and api.SetActiveUnit) then
		return
	end
	local unit = "player"
	if UnitHasVehicleUI then
		local ok, inVehicle = pcall(UnitHasVehicleUI, "player")
		if ok and inVehicle then
			unit = "vehicle"
		end
	end
	pcall(api.SetActiveUnit, unit)
end

function ns.ApplyBlizzardText()
	local frame = _G.CombatText
	if not frame or type(frame.Hide) ~= "function" then
		return
	end
	if CombatTextMasterDB and CombatTextMasterDB.enabled then
		pcall(frame.Hide, frame)
	elseif frame.Show then
		pcall(frame.Show, frame)
	end
	ns.ClaimFeed()
end

local function EventInfo()
	local api = C_CombatText
	if not (api and api.GetCurrentEventInfo) then
		return nil
	end
	local ok, value, extra, third = pcall(api.GetCurrentEventInfo)
	if not ok then
		return nil
	end
	return value, extra, third
end

local function Repeated(name)
	local now = GetTime()
	local last = recentAlerts[name]
	recentAlerts[name] = now
	return last ~= nil and (now - last) < REPEAT_WINDOW
end

local function ShowAmount(colorName, crit, amount)
	if amount == nil or not ns.ShowCombatText then
		return
	end
	local color = COLORS[colorName]
	local readable = ns.Readable(amount)
	if readable then
		ns.ShowCombatText("incoming", color[1], color[2], color[3], crit, "-" .. tostring(readable))
	else
		ns.ShowCombatText("incoming", color[1], color[2], color[3], crit, "-%s", amount)
	end
end

local function OnCombatText(messageType)
	if type(messageType) ~= "string" then
		return
	end
	if messageType == "SPELL_ACTIVE" then
		local name = EventInfo()
		if name == nil or not ns.ShowCombatText then
			return
		end
		local named = ns.ReadableString(name)
		if named then
			local alert = ns.ReactiveByName(named)
			if not alert or not ns.AlertEnabled(alert.id) then
				return
			end
			if Repeated(named) then
				return
			end
		end
		local color = COLORS.alert
		if named then
			ns.ShowCombatText("reactive", color[1], color[2], color[3], true, "<" .. named .. ">")
		else
			ns.ShowCombatText("reactive", color[1], color[2], color[3], true, "<%s>", name)
		end
		return
	end

	local info = DAMAGE_TYPES[messageType]
	if not info then
		return
	end
	feedCarriesHits = true
	local amount = EventInfo()
	ShowAmount(info.color, info.crit, amount)
end

local cooling = {}

local function CooldownIsActive(info)
	if type(info) ~= "table" or ns.IsSecret(info) then
		return nil
	end
	local active = info.isActive
	if ns.IsSecret(active) then
		return nil
	end
	if not active then
		return false
	end
	local onGcd = info.isOnGCD
	if onGcd == true then
		return false
	end
	local duration = info.duration
	if not ns.IsSecret(duration) then
		local seconds = tonumber(duration)
		if seconds and seconds > 0 and seconds <= 1.5 then
			return false
		end
	end
	return true
end

local function ReadCooldown(spellID)
	if not (C_Spell and C_Spell.GetSpellCooldown) then
		return nil
	end
	local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
	if not ok then
		return nil
	end
	return CooldownIsActive(info)
end

local function ShowReady(name)
	if not ns.ShowCombatText or Repeated(name) then
		return
	end
	local color = COLORS.alert
	ns.ShowCombatText("reactive", color[1], color[2], color[3], true, "<" .. name .. ">")
end

function ns.WatchCooldowns(announce)
	if not CombatTextMasterDB or not CombatTextMasterDB.enabled then
		return
	end
	for i = 1, #ns.ALERTS do
		local alert = ns.ALERTS[i]
		if alert.kind == "cooldown" and ns.AlertEnabled(alert.id) and ns.AlertKnown(alert) then
			local active = ReadCooldown(ns.KnownSpellID(alert))
			if active ~= nil then
				if announce and cooling[alert.id] and not active then
					ShowReady(ns.AlertName(alert))
				end
				cooling[alert.id] = active
			end
		else
			cooling[alert.id] = nil
		end
	end
end

local function OnUnitCombat(unit, action, descriptor, amount, school)
	if unit ~= "player" or feedCarriesHits or action ~= "WOUND" then
		return
	end
	local physical = ns.Readable(school)
	local colorName = "spell"
	if physical == nil or physical == 1 then
		colorName = "damage"
	end
	ShowAmount(colorName, descriptor == "CRITICAL", amount)
end

local function HandleSlash(msg)
	ns.InitDB()
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "on" then
		CombatTextMasterDB.enabled = true
		ns.ApplyBlizzardText()
		Print(StatusText())
	elseif msg == "off" then
		CombatTextMasterDB.enabled = false
		ns.ApplyBlizzardText()
		Print(StatusText())
	elseif msg == "status" then
		Print(StatusText() .. "  " .. ns.FaceLabel() .. " " .. tostring(ns.FontSize(false)) .. " " .. CombatTextMasterDB.outline)
	elseif msg == "alerts" then
		if ns.ShowWindow then
			ns.ShowWindow("alerts")
		end
	else
		PrintMenu()
		if ns.ShowWindow then
			ns.ShowWindow("look")
		end
	end
end

SLASH_COMBATTEXTMASTER1 = "/ctm"
SLASH_COMBATTEXTMASTER2 = "/combattext"
SlashCmdList["COMBATTEXTMASTER"] = HandleSlash

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == addonName then
			ns.InitDB()
		elseif name == "Blizzard_CombatText" then
			ns.InitDB()
			ns.ApplyBlizzardText()
		end
		return
	end
	if event == "PLAYER_LOGIN" then
		ns.InitDB()
		if ns.InitDisplay then
			ns.InitDisplay()
		end
		if ns.InitWindow then
			ns.InitWindow()
		end
		EnsureFeed()
		ns.EnsureOutgoing()
		ns.ApplyBlizzardText()
		ns.WatchCooldowns(false)
		Print("loaded. Type /ctm for the menu.")
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITING_VEHICLE" then
		ns.ClaimFeed()
		if event == "PLAYER_ENTERING_WORLD" then
			ns.ApplyBlizzardText()
		end
		return
	end
	if event == "COMBAT_TEXT_UPDATE" then
		OnCombatText(...)
		return
	end
	if event == "UNIT_COMBAT" then
		OnUnitCombat(...)
		return
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		ns.WatchCooldowns(true)
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_TEXT_UPDATE")
frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
frame:RegisterEvent("UNIT_EXITING_VEHICLE")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
if frame.RegisterUnitEvent then
	frame:RegisterUnitEvent("UNIT_COMBAT", "player")
else
	frame:RegisterEvent("UNIT_COMBAT")
end
