local _, ns = ...

local pulse
local pulseTex
local elapsedTotal = 0
local trackingOn = false

-- Find Herbs 2383, Find Minerals 2580
-- https://warcraft.wiki.gg/wiki/API_C_Minimap.GetTrackingInfo
-- https://warcraft.wiki.gg/wiki/API_C_Minimap.GetNumTrackingTypes
local FIND_SPELLS = {
	[2383] = true,
	[2580] = true,
}

local function IsGatherTracking()
	if not C_Minimap or not C_Minimap.GetNumTrackingTypes or not C_Minimap.GetTrackingInfo then
		return false
	end
	local count = C_Minimap.GetNumTrackingTypes() or 0
	for i = 1, count do
		local info = C_Minimap.GetTrackingInfo(i)
		if info and info.active then
			if info.spellID and FIND_SPELLS[info.spellID] then
				return true
			end
			local name = string.lower(info.name or "")
			if string.find(name, "herb", 1, true) or string.find(name, "mineral", 1, true) then
				return true
			end
		end
	end
	return false
end

function ns.UpdatePulseState()
	trackingOn = IsGatherTracking()
	if not pulse then
		return
	end
	if ns.IsEnabled() and trackingOn and Minimap and Minimap:IsVisible() then
		pulse:Show()
	else
		pulse:Hide()
	end
end

local function OnPulseUpdate(_, elapsed)
	if not pulseTex or not ns.IsEnabled() or not trackingOn then
		return
	end
	elapsedTotal = elapsedTotal + elapsed
	local speed = 1.05
	local maxAlpha = 0.45
	local cycle = elapsedTotal % speed
	local t = cycle / speed
	local size = (TobarisuMapDB.size or 200) * (0.15 + t * 0.85)
	pulseTex:SetSize(size, size)
	pulseTex:SetAlpha(maxAlpha * (1 - t))
end

function ns.InitPulse()
	if pulse or not Minimap then
		return
	end
	pulse = CreateFrame("Frame", nil, Minimap)
	pulse:SetAllPoints(Minimap)
	pulse:EnableMouse(false)
	pulse:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 2)
	pulseTex = pulse:CreateTexture(nil, "OVERLAY")
	pulseTex:SetPoint("CENTER")
	pulseTex:SetTexture("Interface\\Minimap\\Ping\\MiniMap-PingCircle")
	pulseTex:SetBlendMode("ADD")
	pulseTex:SetVertexColor(0.45, 1, 0.45)
	pulse:SetScript("OnUpdate", OnPulseUpdate)
	ns.pulse = pulse

	pulse:RegisterEvent("MINIMAP_UPDATE_TRACKING")
	pulse:RegisterEvent("PLAYER_ENTERING_WORLD")
	pulse:SetScript("OnEvent", function()
		ns.UpdatePulseState()
	end)
	ns.UpdatePulseState()
end
