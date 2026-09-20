local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cffffcc66BagMaster|r"
ns.COLUMNS = 10
ns.ITEM_SPACING_X = 5
ns.ITEM_SPACING_Y = 5
ns.HEADER_HEIGHT = 14
ns.HEADER_GAP = 1
ns.SECTION_GAP = 6
ns.HEADER_TEXT_INSET = 18 -- icon (14) + gap (4)
ns.HEADER_NAME_MAX = 16
ns.BAG_SCALE = 1.3 -- Combined Bags often auto-scales down; bump for readability

local function Print(message)
	print(ns.PREFIX .. ": " .. message)
end

ns.Print = Print

local function BoolText(value)
	if value then
		return "ON"
	end
	return "OFF"
end

function ns.IsEnabled()
	return BagMasterDB and BagMasterDB.enabled
end

function ns.InitDB()
	if type(BagMasterDB) ~= "table" then
		BagMasterDB = {}
	end
	if BagMasterDB.enabled == nil then
		BagMasterDB.enabled = true
	end
end

local function StatusText()
	return BoolText(ns.IsEnabled())
end

local function PrintMenu()
	Print("/bm on | off | status")
	print("Currently: " .. StatusText())
end

local function PrintStatus()
	Print(StatusText())
end

local function CaptureCombinedBagsCVar()
	if BagMasterDB.combinedBagsWasOn == nil then
		BagMasterDB.combinedBagsWasOn = GetCVarBool("combinedBags")
	end
end

local function ApplyCombinedBagsCVar()
	CaptureCombinedBagsCVar()
	if not GetCVarBool("combinedBags") then
		SetCVar("combinedBags", 1)
		return
	end
	ns.RefreshBags()
end

local function RestoreCombinedBagsCVar()
	local wasOn = BagMasterDB.combinedBagsWasOn
	BagMasterDB.combinedBagsWasOn = nil
	if wasOn == false then
		SetCVar("combinedBags", 0)
		return
	end
	ns.RefreshBags()
end

function ns.SetEnabled(enabled)
	local turningOn = enabled and not ns.IsEnabled()
	local turningOff = (not enabled) and ns.IsEnabled()
	BagMasterDB.enabled = enabled
	if turningOn then
		ApplyCombinedBagsCVar()
	elseif turningOff then
		ns.HideHeaders()
		RestoreCombinedBagsCVar()
	end
	PrintStatus()
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "on" then
		ns.SetEnabled(true)
	elseif msg == "off" then
		ns.SetEnabled(false)
	elseif msg == "status" then
		PrintStatus()
	else
		PrintMenu()
	end
end

local function Start()
	ns.InitDB()
	if ns.InitLayout() then
		if ns.IsEnabled() then
			ApplyCombinedBagsCVar()
		end
		return true
	end
	return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedName)
	if event == "ADDON_LOADED" and loadedName == addonName then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		if not Start() then
			self:RegisterEvent("PLAYER_ENTERING_WORLD")
		end
		Print("loaded. Type /bm for the menu.")
	elseif event == "PLAYER_ENTERING_WORLD" then
		if Start() then
			self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		end
	end
end)

SLASH_BAGMASTER1 = "/bm"
SLASH_BAGMASTER2 = "/bagmaster"
SlashCmdList["BAGMASTER"] = HandleSlash
