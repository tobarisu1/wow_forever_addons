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
local pinHost
local squareMinimap = false

local function PinHost()
	if pinHost and pinHost:GetParent() == Minimap then
		return pinHost
	end
	pinHost = CreateFrame("Frame", "GatherMemoryMinimapPins", Minimap)
	pinHost:SetAllPoints(Minimap)
	pinHost:SetFrameStrata("HIGH")
	pinHost:SetFrameLevel(60)
	pinHost.__tmapKeepShown = true
	pinHost.__gatherMemoryPin = true
	return pinHost
end

local function TobarisuMapLoaded()
	-- https://warcraft.wiki.gg/wiki/API_C_AddOns.IsAddOnLoaded
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local loadedOrLoading = C_AddOns.IsAddOnLoaded("TobarisuMap")
		if loadedOrLoading then
			return true
		end
	end
	return TobarisuMap ~= nil
end

local function ViewRadius()
	local radius
	pcall(function()
		if C_Minimap and C_Minimap.GetViewRadius then
			radius = C_Minimap.GetViewRadius()
		end
	end)
	local ok, valid = pcall(function()
		return radius and radius > 1 and radius < 2000
	end)
	if ok and valid then
		return radius
	end
	local zoom = 0
	pcall(function()
		if Minimap.GetZoom then
			zoom = Minimap:GetZoom() or 0
		end
	end)
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

local function PinHalfSize()
	local w, h
	pcall(function()
		w = Minimap:GetWidth()
		h = Minimap:GetHeight()
	end)
	local ok = pcall(function()
		if not w or w < 10 then
			w = 300
		end
		if not h or h < 10 then
			h = 300
		end
	end)
	if not ok then
		return 150, 150
	end
	return w / 2, h / 2
end

local function AcquirePin()
	local pin = table.remove(pinPool)
	if pin then
		return pin
	end
	pin = CreateFrame("Button", nil, PinHost())
	pin:SetSize(ns.MINIMAP_PIN_SIZE, ns.MINIMAP_PIN_SIZE)
	pin:SetFrameStrata("HIGH")
	pin:SetFrameLevel(50)
	pin:EnableMouse(true)
	pin.__tmapKeepShown = true
	pin.__gatherMemoryPin = true
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

local function PlaceOnMinimap(node, loc, radius, halfW, halfH, rotate, sinFacing, cosFacing)
	if not loc or not loc.x or not loc.y or not node or not node.x or not node.y then
		return nil
	end
	local playerX = ns.PublicNumber(loc.x)
	local playerY = ns.PublicNumber(loc.y)
	local nodeX = ns.PublicNumber(node.x)
	local nodeY = ns.PublicNumber(node.y)
	if not playerX or not playerY or not nodeX or not nodeY then
		return nil
	end
	local mapW, mapH
	if C_Map and C_Map.GetMapWorldSize then
		mapW, mapH = C_Map.GetMapWorldSize(ns.PublicNumber(loc.uiMapID) or loc.uiMapID)
		mapW = ns.PublicNumber(mapW)
		mapH = ns.PublicNumber(mapH)
	end
	if not mapW or not mapH or mapW == 0 or mapH == 0 then
		mapW, mapH = 1000, 1000
	end
	radius = ns.PublicNumber(radius) or 150
	halfW = ns.PublicNumber(halfW) or 150
	halfH = ns.PublicNumber(halfH) or 150
	-- Map coords run +x east and +y south; the minimap runs +x east and +y north.
	local east = (nodeX - playerX) * mapW
	local north = (playerY - nodeY) * mapH
	if rotate then
		-- GetPlayerFacing is 0 at north and increases counterclockwise, so forward
		-- is (-sin, cos) in east/north terms. Rotate that onto screen up.
		east, north = east * cosFacing + north * sinFacing, north * cosFacing - east * sinFacing
	end
	local diffX = east / radius
	local diffY = north / radius
	if squareMinimap then
		if diffX > 1 then
			diffX = 1
		elseif diffX < -1 then
			diffX = -1
		end
		if diffY > 1 then
			diffY = 1
		elseif diffY < -1 then
			diffY = -1
		end
	else
		local dist = math.sqrt(diffX * diffX + diffY * diffY)
		if dist > 0.9 then
			diffX = diffX / dist * 0.9
			diffY = diffY / dist * 0.9
		end
	end
	return diffX * halfW, diffY * halfH
end

function ns.UpdateMinimap(force)
	if not updater then
		return
	end
	if ns.GetSetting("showMinimap") == false then
		ReleaseAll()
		return
	end
	if not Minimap then
		return
	end
	squareMinimap = TobarisuMapLoaded()
	if squareMinimap then
		ns.MINIMAP_PIN_SIZE = 20
	end

	local loc = ns.GetPlayerLocation(true)
	local radius = ViewRadius()
	local width, height = PinHalfSize()
	local facing = ns.PublicNumber(GetPlayerFacing()) or 0
	local rotate = RotateMinimap()
	local sinFacing, cosFacing = math.sin(facing), math.cos(facing)

	local needed = {}
	ns.ForEachNode(function(node)
		if ns.IsKindShown(node.kind) == false then
			return
		end
		local px, py = PlaceOnMinimap(node, loc, radius, width, height, rotate, sinFacing, cosFacing)
		if px == nil or py == nil then
			return
		end
		needed[#needed + 1] = {
			node = node,
			x = px,
			y = py,
		}
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
		pin:SetParent(PinHost())
		pin:SetFrameStrata("HIGH")
		pin:SetFrameLevel(50)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", PinHost(), "CENTER", item.x, item.y)
		pin.__tmapKeepShown = true
		pin:Show()
	end
end

-- Prints the raw numbers the client hands back, so a bad pin position can be
-- traced to the input that caused it instead of being guessed at.
function ns.DescribeMinimap()
	local loc = ns.GetPlayerLocation(true)
	if not loc then
		print("player position unavailable (secret value or no map)")
		return
	end
	print(string.format("player: map %s at %.4f, %.4f", tostring(loc.uiMapID), loc.x, loc.y))
	local rawW, rawH
	if C_Map and C_Map.GetMapWorldSize then
		rawW, rawH = C_Map.GetMapWorldSize(loc.uiMapID)
	end
	print(string.format("map world size: %s x %s yards (usable %s x %s)",
		tostring(rawW), tostring(rawH), tostring(ns.PublicNumber(rawW)), tostring(ns.PublicNumber(rawH))))
	local radius = ViewRadius()
	local halfW, halfH = PinHalfSize()
	local rotate = RotateMinimap()
	local facing = ns.PublicNumber(GetPlayerFacing())
	print(string.format("view radius: %s yards, minimap half-size %.0f x %.0f", tostring(radius), halfW, halfH))
	print(string.format("square: %s, rotating: %s, facing: %s",
		tostring(squareMinimap), tostring(rotate), tostring(facing)))
	local sinFacing, cosFacing = math.sin(facing or 0), math.cos(facing or 0)
	local shown = 0
	ns.ForEachNode(function(node)
		local px, py = PlaceOnMinimap(node, loc, radius, halfW, halfH, rotate, sinFacing, cosFacing)
		local mapW = ns.PublicNumber(rawW) or 1000
		local mapH = ns.PublicNumber(rawH) or 1000
		local east = (node.x - loc.x) * mapW
		local north = (loc.y - node.y) * mapH
		shown = shown + 1
		print(string.format("  %s (%s) at %.4f,%.4f | %.0fy east %.0fy north | pin %s,%s",
			tostring(node.name), tostring(node.kind), node.x, node.y, east, north,
			px and string.format("%.0f", px) or "nil",
			py and string.format("%.0f", py) or "nil"))
	end)
	if shown == 0 then
		print("  no nodes to place")
	end
end

function ns.InitMinimap()
	if updater then
		return
	end
	squareMinimap = TobarisuMapLoaded()
	if squareMinimap then
		ns.MINIMAP_PIN_SIZE = 20
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

function ns.RebuildMinimap()
	ReleaseAll()
	for i = #pinPool, 1, -1 do
		pinPool[i] = nil
	end
	if not updater then
		ns.InitMinimap()
		return
	end
	ns.UpdateMinimap(true)
end
