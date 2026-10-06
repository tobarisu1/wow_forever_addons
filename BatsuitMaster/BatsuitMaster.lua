local addonName, ns = ...

ns.addonName = addonName
ns.PREFIX = "|cffffcc66BatsuitMaster|r"
ns.SUIT_COUNT = 5

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

function ns.PlainString(value)
	if type(value) ~= "string" or value == "" or ns.IsSecret(value) then
		return nil
	end
	return value
end

function ns.InitDB()
	if type(BatsuitMasterDB) ~= "table" then
		BatsuitMasterDB = {}
	end
	if type(BatsuitMasterDB.version) ~= "number" or BatsuitMasterDB.version < 2 then
		BatsuitMasterDB.version = 2
		if type(BatsuitMasterDB.scale) ~= "number" or BatsuitMasterDB.scale == 1 then
			BatsuitMasterDB.scale = 1.3
		end
	end
	if type(BatsuitMasterDB.characters) ~= "table" then
		BatsuitMasterDB.characters = {}
	end
	if type(BatsuitMasterDB.scale) ~= "number" then
		BatsuitMasterDB.scale = 1.3
	end
end

local function StatusText()
	local shown = "HIDDEN"
	if ns.IsWindowShown and ns.IsWindowShown() then
		shown = "SHOWN"
	end
	local suit = "Suit"
	if ns.SuitName then
		suit = ns.SuitName()
	end
	local ready = "waiting on bags"
	if ns.CanSuitUp and ns.CanSuitUp() then
		ready = "ready"
	end
	local scale = 100
	if ns.GetScale then
		scale = math.floor((ns.GetScale() * 100) + 0.5)
	end
	return shown .. ". " .. suit .. ". Suit Up " .. ready .. ". Scale " .. scale .. "%"
end

local function PrintMenu()
	ns.Print("/bsm on | off | status")
	print("Currently: " .. StatusText())
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "on" then
		if ns.ShowWindow then
			ns.ShowWindow()
		end
		ns.Print(StatusText())
	elseif msg == "off" then
		if ns.HideWindow then
			ns.HideWindow()
		end
		ns.Print(StatusText())
	elseif msg == "status" then
		ns.Print(StatusText())
	else
		if ns.ShowWindow and not (ns.IsWindowShown and ns.IsWindowShown()) then
			ns.ShowWindow()
		end
		PrintMenu()
	end
end

local function OnLogin()
	ns.InitDB()
	if ns.EnsureCharacter then
		ns.EnsureCharacter()
	end
	if ns.InitWindow then
		ns.InitWindow()
	end
	if type(BackendMaster) == "table" and type(BackendMaster.RegisterCallback) == "function" then
		BackendMaster.RegisterCallback("Ready", function()
			if ns.EnsureCharacter then
				ns.EnsureCharacter()
			end
			if ns.RefreshWindow then
				ns.RefreshWindow()
			end
		end)
		BackendMaster.RegisterCallback("BagCacheUpdate", function()
			if ns.RefreshWindow then
				ns.RefreshWindow()
			end
		end)
	end
	ns.Print("loaded. Type /bsm for the menu.")
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
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if ns.RefreshWindow then
			ns.RefreshWindow()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if ns.OnLeavingCombat then
			ns.OnLeavingCombat()
		end
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_BATSUITMASTER1 = "/bsm"
SLASH_BATSUITMASTER2 = "/batsuitmaster"
SlashCmdList["BATSUITMASTER"] = HandleSlash
