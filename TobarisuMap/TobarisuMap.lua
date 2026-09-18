local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cff66ccffTobarisuMap|r"
ns.HEADER_HEIGHT = 18
ns.WIDGET_GAP = 4
ns.IDLE_ZOOM_DELAY = 10
ns.IDLE_ZOOM_STEP = 0.4

TobarisuMap = TobarisuMap or {}

local defaults = {
	version = 1,
	enabled = true,
	locked = true,
	size = 300,
	homeZoom = 0,
	point = "TOPRIGHT",
	x = -10,
	y = -10,
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
	if type(TobarisuMapDB) ~= "table" then
		TobarisuMapDB = {}
	end
	CopyDefaults(defaults, TobarisuMapDB)
	if TobarisuMapDB.size == 200 then
		TobarisuMapDB.size = 300
	end
end

function ns.IsEnabled()
	return TobarisuMapDB and TobarisuMapDB.enabled
end

function ns.IsLocked()
	return TobarisuMapDB and TobarisuMapDB.locked
end

local function BoolText(value)
	if value then
		return "ON"
	end
	return "OFF"
end

local function PrintStatus()
	ns.Print("map " .. BoolText(ns.IsEnabled()) .. "  locked " .. BoolText(ns.IsLocked()) .. "  zoom " .. tostring(TobarisuMapDB.homeZoom))
end

local function PrintMenu()
	ns.Print("/tmap on | off | status")
	print("/tmap lock | unlock")
	print("/tmap zoom <0-5>")
	print("/tmap dump")
	PrintStatus()
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
	if msg == "on" then
		ns.SetEnabled(true)
		ns.Print("ON")
		return
	end
	if msg == "off" then
		ns.SetEnabled(false)
		ns.Print("OFF")
		return
	end
	if msg == "lock" then
		ns.SetLocked(true)
		ns.Print("locked")
		return
	end
	if msg == "unlock" then
		ns.SetLocked(false)
		ns.Print("unlocked - drag the map to move it")
		return
	end
	local zoom = string.match(msg, "^zoom%s+(%d+)$")
	if zoom then
		ns.SetHomeZoom(tonumber(zoom))
		return
	end
	if msg == "zoom" then
		ns.Print("home zoom " .. tostring(TobarisuMapDB.homeZoom))
		return
	end
	if msg == "dump" then
		if ns.DumpMinimapChrome then
			ns.DumpMinimapChrome()
		end
		return
	end
	PrintMenu()
end

function TobarisuMap.GetMinimap()
	return Minimap
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedName)
	if event == "ADDON_LOADED" and loadedName == addonName then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		ns.InitDB()
		if ns.InitLayout then
			ns.InitLayout()
		end
		if ns.InitZoom then
			ns.InitZoom()
		end
		if ns.InitWidgets then
			ns.InitWidgets()
		end
		if ns.InitPulse then
			ns.InitPulse()
		end
		ns.Print("loaded. Type /tmap for the menu.")
	end
end)

SLASH_TOBARISUMAP1 = "/tmap"
SLASH_TOBARISUMAP2 = "/tobarisumap"
SlashCmdList["TOBARISUMAP"] = HandleSlash
