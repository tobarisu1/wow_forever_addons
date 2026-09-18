local _, ns = ...

local ZOOM_RADIUS = {
	[0] = 233.3333,
	[1] = 200,
	[2] = 166.6667,
	[3] = 133.3333,
	[4] = 100,
	[5] = 66.6667,
}

local activePins = {}
local pinPool = {}
local updater

local function ViewRadius()
	if C_Minimap and C_Minimap.GetViewRadius then
		local radius = C_Minimap.GetViewRadius()
		if radius and radius > 0 then
			return radius
		end
	end
	local zoom = 0
	if Minimap.GetZoom then
		zoom = Minimap:GetZoom() or 0
	end
	return ZOOM_RADIUS[zoom] or 150
end

local function RotateMinimap()
	if C_CVar and C_CVar.GetCVar then
		return C_CVar.GetCVar("rotateMinimap") == "1"
	end
	if GetCVar then
		return GetCVar("rotateMinimap") == "1"
	end
	return false
end

local function AcquirePin()
	local pin = table.remove(pinPool)
	if pin then
		return pin
	end
	pin = CreateFrame("Button", nil, Minimap)
	pin:SetSize(ns.MINIMAP_PIN_SIZE, ns.MINIMAP_PIN_SIZE)
	pin:SetFrameStrata(Minimap:GetFrameStrata() or "LOW")
	pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	pin:EnableMouse(true)
	pin.texture = pin:CreateTexture(nil, "OVERLAY")
	pin.texture:SetAllPoints()
	pin.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pin:SetScript("OnEnter", function(self)
		ns.ShowNodeTooltip(self, self.node)
	end)
	pin:SetScript("OnLeave", function()
		ns.HideNodeTooltip()
	end)
	return pin
end

local function ReleasePin(pin)
	pin:Hide()
	pin.node = nil
	pinPool[#pinPool + 1] = pin
end

local function ReleaseAll()
	for i = 1, #activePins do
		ReleasePin(activePins[i])
		activePins[i] = nil
	end
end

local function PlayerWorld()
	local wy, wx, _, instance = UnitPosition("player")
	if wx and wy then
		return wx, wy, instance
	end
	local loc = ns.GetPlayerLocation()
	if loc then
		return loc.wx, loc.wy, loc.instance
	end
	return nil
end

function ns.UpdateMinimap(force)
	if not updater then
		return
	end
	if not ns.GetSetting("showMinimap") or not Minimap:IsVisible() then
		ReleaseAll()
		return
	end

	local playerX, playerY, instance = PlayerWorld()
	if not playerX or not playerY then
		ReleaseAll()
		return
	end

	local radius = ViewRadius()
	local width = Minimap:GetWidth() / 2
	local height = Minimap:GetHeight() / 2
	local facing = GetPlayerFacing() or 0
	local rotate = RotateMinimap()
	local sinFacing = math.sin(facing)
	local cosFacing = math.cos(facing)

	local needed = {}
	ns.ForEachNode(function(node)
		if not ns.IsKindShown(node.kind) then
			return
		end
		if not node.wx or not node.wy then
			return
		end
		if node.instance ~= nil and instance ~= nil and node.instance ~= instance then
			return
		end
		local xDist = playerX - node.wx
		local yDist = playerY - node.wy
		if rotate then
			local dx, dy = xDist, yDist
			xDist = dx * cosFacing - dy * sinFacing
			yDist = dx * sinFacing + dy * cosFacing
		end
		local diffX = xDist / radius
		local diffY = yDist / radius
		local dist2 = (diffX * diffX + diffY * diffY) / (0.9 * 0.9)
		if dist2 <= 1 then
			needed[#needed + 1] = {
				node = node,
				x = diffX * width,
				y = -diffY * height,
			}
		end
	end)

	while #activePins > #needed do
		ReleasePin(table.remove(activePins))
	end
	while #activePins < #needed do
		activePins[#activePins + 1] = AcquirePin()
	end

	for i = 1, #needed do
		local pin = activePins[i]
		local item = needed[i]
		if force or pin.node ~= item.node then
			pin.node = item.node
			pin.texture:SetTexture(ns.GetNodeIcon(item.node.name, item.node.kind))
		end
		pin:SetSize(ns.MINIMAP_PIN_SIZE, ns.MINIMAP_PIN_SIZE)
		pin:SetParent(Minimap)
		pin:SetFrameStrata(Minimap:GetFrameStrata() or "LOW")
		pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", Minimap, "CENTER", item.x, item.y)
		pin:Show()
	end
end

function ns.InitMinimap()
	if updater then
		return
	end
	updater = CreateFrame("Frame")
	updater.elapsed = 0
	updater:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < 0.08 then
			return
		end
		self.elapsed = 0
		ns.UpdateMinimap(false)
	end)
	updater:RegisterEvent("PLAYER_ENTERING_WORLD")
	updater:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	updater:RegisterEvent("CVAR_UPDATE")
	updater:SetScript("OnEvent", function(_, event, cvar)
		if event == "CVAR_UPDATE" and cvar ~= "rotateMinimap" then
			return
		end
		ns.UpdateMinimap(true)
	end)
	ns.UpdateMinimap(true)
end
