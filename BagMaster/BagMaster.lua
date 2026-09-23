local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cffffcc66BagMaster|r"

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
	if BagMasterDB.layout ~= "bags" and BagMasterDB.layout ~= "category" then
		BagMasterDB.layout = "category"
	end
	if BagMasterDB.highlightItems == nil then
		if type(OldManQuesterDB) == "table" and OldManQuesterDB.highlightItems ~= nil then
			BagMasterDB.highlightItems = OldManQuesterDB.highlightItems and true or false
		end
	end
end

function ns.GetLayout()
	if BagMasterDB and BagMasterDB.layout == "bags" then
		return "bags"
	end
	return "category"
end

local function StatusText()
	return BoolText(ns.IsEnabled())
end

local function ItemsStatusText()
	return BoolText(ns.IsItemsEnabled())
end

local function PrintMenu()
	Print("/bm on | off | status")
	print("/bm bags | categories")
	print("/bm items on | off")
	print("/bm search")
	Print("Currently: " .. StatusText() .. "  layout " .. ns.GetLayout() .. "  items " .. ItemsStatusText())
end

local function PrintStatus()
	Print(StatusText() .. "  layout " .. ns.GetLayout() .. "  items " .. ItemsStatusText())
end

function ns.SetEnabled(enabled)
	local turningOff = (not enabled) and ns.IsEnabled()
	BagMasterDB.enabled = enabled
	if turningOff then
		ns.HideWindow()
	end
	if ns.RefreshBagHighlights then
		ns.RefreshBagHighlights()
	end
	PrintStatus()
end

function ns.SetLayout(layout)
	BagMasterDB.layout = layout
	ns.RefreshBags()
	Print("layout " .. layout)
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
	if msg == "on" then
		ns.SetEnabled(true)
		return
	end
	if msg == "off" then
		ns.SetEnabled(false)
		return
	end
	if msg == "status" then
		PrintStatus()
		return
	end
	if msg == "bags" then
		ns.SetLayout("bags")
		return
	end
	if msg == "categories" or msg == "category" then
		ns.SetLayout("category")
		return
	end
	if msg == "search" then
		ns.FocusSearch()
		return
	end
	local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
	if cmd == "items" then
		local value = ParseOnOff(rest)
		if value == nil then
			Print("/bm items on | off")
			return
		end
		ns.SetItemsEnabled(value)
		return
	end
	PrintMenu()
end

local function Start()
	ns.InitDB()
	if BagMasterDB.highlightItems == nil then
		BagMasterDB.highlightItems = true
	end
	local itemsReady = ns.InitItems()
	ns.InitWindow()
	ns.InitLayout()
	return itemsReady
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
