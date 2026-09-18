local _, ns = ...

local idleFrame
local idleElapsed = 0
local stepping = false
local stepElapsed = 0

local function MaxZoom()
	-- https://warcraft.wiki.gg/wiki/API_Minimap_GetZoomLevels
	if Minimap and Minimap.GetZoomLevels then
		local levels = Minimap:GetZoomLevels()
		if levels and levels > 0 then
			return levels - 1
		end
	end
	return 5
end

local function ClampZoom(zoom)
	zoom = math.floor(tonumber(zoom) or 0)
	if zoom < 0 then
		zoom = 0
	end
	local maxZoom = MaxZoom()
	if zoom > maxZoom then
		zoom = maxZoom
	end
	return zoom
end

local function CurrentZoom()
	-- https://warcraft.wiki.gg/wiki/API_Minimap_GetZoom
	if Minimap and Minimap.GetZoom then
		return Minimap:GetZoom() or 0
	end
	return 0
end

local function ApplyZoom(zoom)
	-- https://warcraft.wiki.gg/wiki/API_Minimap_SetZoom
	if Minimap and Minimap.SetZoom then
		Minimap:SetZoom(ClampZoom(zoom))
	end
end

function ns.NotifyZoomActivity()
	idleElapsed = 0
	stepping = false
	stepElapsed = 0
end

function ns.SetHomeZoom(zoom)
	zoom = ClampZoom(zoom)
	TobarisuMapDB.homeZoom = zoom
	ApplyZoom(zoom)
	ns.NotifyZoomActivity()
	ns.Print("home zoom " .. tostring(zoom))
end

function ns.ApplyHomeZoom()
	ApplyZoom(TobarisuMapDB.homeZoom or 0)
end

local function OnMouseWheel(_, delta)
	if not ns.IsEnabled() then
		return
	end
	local nextZoom = ClampZoom(CurrentZoom() + delta)
	ApplyZoom(nextZoom)
	ns.NotifyZoomActivity()
end

local function OnIdleUpdate(_, elapsed)
	if not ns.IsEnabled() or not Minimap then
		return
	end
	local home = ClampZoom(TobarisuMapDB.homeZoom or 0)
	local current = CurrentZoom()
	if current == home then
		idleElapsed = 0
		stepping = false
		return
	end
	if not stepping then
		idleElapsed = idleElapsed + elapsed
		if idleElapsed < ns.IDLE_ZOOM_DELAY then
			return
		end
		stepping = true
		stepElapsed = 0
	end
	stepElapsed = stepElapsed + elapsed
	if stepElapsed < ns.IDLE_ZOOM_STEP then
		return
	end
	stepElapsed = 0
	if current > home then
		ApplyZoom(current - 1)
	else
		ApplyZoom(current + 1)
	end
end

function ns.InitZoom()
	if not Minimap then
		return
	end
	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", OnMouseWheel)
	ApplyZoom(TobarisuMapDB.homeZoom or 0)

	if idleFrame then
		return
	end
	idleFrame = CreateFrame("Frame")
	idleFrame:SetScript("OnUpdate", OnIdleUpdate)
end
