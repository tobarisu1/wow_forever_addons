local PREFIX = "|cff00ccffCursorTooltip|r"

local function Print(message)
	print(PREFIX .. ": " .. message)
end

local function StatusText()
	if CursorTooltipDB.enabled then
		return "ON"
	end
	return "OFF"
end

local function PrintMenu()
	Print("/mtt on | off | status")
	print("Currently: " .. StatusText())
end

local function SetEnabled(enabled)
	CursorTooltipDB.enabled = enabled
	Print(StatusText())
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "on" then
		SetEnabled(true)
	elseif msg == "off" then
		SetEnabled(false)
	elseif msg == "status" then
		Print(StatusText())
	else
		PrintMenu()
	end
end

local function InitDB()
	if type(CursorTooltipDB) ~= "table" then
		CursorTooltipDB = {}
	end
	if CursorTooltipDB.enabled == nil then
		CursorTooltipDB.enabled = true
	end
end

local hooked = false

local function HookTooltip()
	if hooked then
		return
	end
	hooked = true
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
		if CursorTooltipDB.enabled then
			tooltip:SetOwner(parent, "ANCHOR_CURSOR")
		end
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		InitDB()
		HookTooltip()
		Print("loaded. Type /mtt for the menu.")
	end
end)

SLASH_CURSORTOOLTIP1 = "/mtt"
SLASH_CURSORTOOLTIP2 = "/cursortooltip"
SlashCmdList["CURSORTOOLTIP"] = HandleSlash
