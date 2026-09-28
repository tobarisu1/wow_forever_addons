local PREFIX = "|cffffcc66TooltipMaster|r"
local USE_LIMIT = 8

local function Print(message)
	print(PREFIX .. ": " .. message)
end

local function StatusText()
	if TooltipMasterDB.enabled then
		return "ON"
	end
	return "OFF"
end

local function PrintMenu()
	Print("/tm on | off | status")
	print("Currently: " .. StatusText())
end

local function SetEnabled(enabled)
	TooltipMasterDB.enabled = enabled
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
	if type(TooltipMasterDB) ~= "table" then
		TooltipMasterDB = {}
	end
	if TooltipMasterDB.enabled == nil then
		TooltipMasterDB.enabled = true
	end
end

local function IsSecret(value)
	if value == nil or not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret
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

local function JunkColor()
	local quality = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor
	if quality == nil then
		quality = 0
	end
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then
		return color.r, color.g, color.b
	end
	return 0.62, 0.62, 0.62
end

local function AddKindLine(tooltip, itemID)
	local described = BackendMaster.DescribeItem(itemID)
	if type(described) ~= "table" or type(described.label) ~= "string" then
		return
	end
	if described.key == "junk" then
		tooltip:AddLine(described.label, JunkColor())
		return
	end
	tooltip:AddLine(described.label, 1, 1, 1)
end

local function AddUseLines(tooltip, itemID)
	if type(BackendMaster.GetItemUses) ~= "function" then
		return
	end
	local uses = BackendMaster.GetItemUses(itemID)
	if type(uses) ~= "table" or #uses == 0 then
		return
	end
	table.sort(uses, function(left, right)
		local leftProfession = left.profession or ""
		local rightProfession = right.profession or ""
		if leftProfession == rightProfession then
			return (left.recipe or "") < (right.recipe or "")
		end
		return leftProfession < rightProfession
	end)
	local shown = 0
	for i = 1, #uses do
		if shown >= USE_LIMIT then
			break
		end
		local row = uses[i]
		if type(row) == "table" and type(row.profession) == "string" and type(row.recipe) == "string" then
			local count = row.count
			if type(count) ~= "number" then
				count = 1
			end
			tooltip:AddLine(row.profession .. ": " .. row.recipe .. " (" .. count .. ")", 1, 1, 1)
			shown = shown + 1
		end
	end
	local extra = #uses - shown
	if extra > 0 then
		tooltip:AddLine("and " .. extra .. " more", 1, 1, 1)
	end
end

local hooked = false

local function HookTooltip()
	if hooked or not TooltipDataProcessor or not Enum or not Enum.TooltipDataType then
		return
	end
	hooked = true
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not TooltipMasterDB or not TooltipMasterDB.enabled then
			return
		end
		if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
			return
		end
		if type(BackendMaster) ~= "table" or type(BackendMaster.DescribeItem) ~= "function" then
			return
		end
		local itemID = PlainNumber(data and data.id)
		if not itemID then
			return
		end
		AddKindLine(tooltip, itemID)
		AddUseLines(tooltip, itemID)
	end)
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		InitDB()
		if type(BackendMaster) == "table" and type(BackendMaster.RegisterCallback) == "function" then
			BackendMaster.RegisterCallback("Ready", HookTooltip)
		end
		Print("loaded. Type /tm for the menu.")
	end
end)
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_TOOLTIPMASTER1 = "/tm"
SLASH_TOOLTIPMASTER2 = "/tooltipmaster"
SlashCmdList["TOOLTIPMASTER"] = HandleSlash
