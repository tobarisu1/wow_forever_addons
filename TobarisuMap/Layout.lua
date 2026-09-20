local _, ns = ...

local chromeHidden = false
local header
local mover

local CHROME_GLOBALS = {
	"MinimapBackdrop",
	"MinimapBorder",
	"MinimapBorderTop",
	"MinimapNorthTag",
	"MinimapCompassTexture",
	"TimeManagerClockButton",
	"AddonCompartmentFrame",
	"ExpansionLandingPageMinimapButton",
	"MiniMapWorldMapButton",
}

local function HideFrame(frame)
	if not frame then
		return
	end
	frame:Hide()
	if frame.__tmapHideHook then
		return
	end
	frame.__tmapHideHook = true
	hooksecurefunc(frame, "Show", function(self)
		if ns.IsEnabled() and not self.__tmapKeepShown then
			self:Hide()
		end
	end)
end

local function HideNamed(name)
	HideFrame(_G[name])
end

function ns.GetCluster()
	if MinimapCluster then
		return MinimapCluster
	end
	return Minimap
end

local function HideChrome()
	if chromeHidden then
		return
	end
	chromeHidden = true

	for i = 1, #CHROME_GLOBALS do
		HideNamed(CHROME_GLOBALS[i])
	end

	if Minimap then
		HideFrame(Minimap.ZoomIn)
		HideFrame(Minimap.ZoomOut)
		HideFrame(Minimap.ZoomHitArea)
		HideFrame(Minimap.BorderTop)
		HideFrame(Minimap.ZoneTextButton)
	end

	local cluster = ns.GetCluster()
	if cluster and cluster ~= Minimap then
		HideFrame(cluster.BorderTop)
		HideFrame(cluster.ZoneTextButton)
		HideFrame(cluster.ZoomIn)
		HideFrame(cluster.ZoomOut)
	end
end

local calendarPlacing = false
local calendarHooked = false

local function CalendarFrame()
	if GameTimeFrame then
		return GameTimeFrame
	end
	local cluster = ns.GetCluster()
	if cluster and cluster.GameTimeFrame then
		return cluster.GameTimeFrame
	end
	return nil
end

local function HookCalendar(calendar)
	if calendarHooked or not calendar then
		return
	end
	calendarHooked = true
	hooksecurefunc(calendar, "SetPoint", function()
		if calendarPlacing or not ns.IsEnabled() then
			return
		end
		ns.PlaceCalendar()
	end)
	hooksecurefunc(calendar, "SetParent", function(_, parent)
		if calendarPlacing or not ns.IsEnabled() then
			return
		end
		if parent ~= UIParent then
			ns.PlaceCalendar()
		end
	end)
end

function ns.PlaceCalendar()
	-- Calendar date button: dock to the top-right corner of the square map.
	local calendar = CalendarFrame()
	if not calendar then
		return
	end
	if calendarPlacing then
		return
	end
	calendarPlacing = true
	calendar.__tmapKeepShown = true
	local anchor = Minimap or ns.GetCluster()
	if not anchor then
		calendarPlacing = false
		return
	end
	HookCalendar(calendar)
	calendar:SetParent(UIParent)
	calendar:ClearAllPoints()
	calendar:SetPoint("CENTER", anchor, "TOPRIGHT", 0, 0)
	calendar:SetSize(28, 28)
	calendar:SetFrameStrata("HIGH")
	calendar:SetFrameLevel(64)
	calendar:EnableMouse(true)
	if calendar.SetMouseClickEnabled then
		calendar:SetMouseClickEnabled(true)
	end
	if calendar.SetMouseMotionEnabled then
		calendar:SetMouseMotionEnabled(true)
	end
	if calendar.SetHitRectInsets then
		calendar:SetHitRectInsets(0, 0, 0, 0)
	end
	if calendar.Enable then
		calendar:Enable()
	end
	calendar:Show()
	ns.HideDayNightCenter()
	calendarPlacing = false
end

local trackingPlacing = false
local trackingHooked = false

local function TrackingFrame()
	local cluster = ns.GetCluster()
	if cluster and cluster.Tracking then
		return cluster.Tracking
	end
	if Minimap and Minimap.Tracking then
		return Minimap.Tracking
	end
	return _G.MiniMapTracking or _G.MiniMapTrackingFrame
end

local function TrackingButton(tracking)
	if tracking and tracking.Button then
		return tracking.Button
	end
	if Minimap and Minimap.TrackingButton then
		return Minimap.TrackingButton
	end
	return _G.MiniMapTrackingButton
end

local function HookTracking(tracking)
	if trackingHooked or not tracking then
		return
	end
	trackingHooked = true
	hooksecurefunc(tracking, "SetPoint", function()
		if trackingPlacing or not ns.IsEnabled() then
			return
		end
		ns.PlaceTracking()
	end)
	hooksecurefunc(tracking, "SetParent", function(_, parent)
		if trackingPlacing or not ns.IsEnabled() then
			return
		end
		if parent ~= UIParent then
			ns.PlaceTracking()
		end
	end)
end

function ns.PlaceTracking()
	-- Tracking / scope button: dock to the top-left corner of the square map.
	local tracking = TrackingFrame()
	if not tracking then
		return
	end
	if trackingPlacing then
		return
	end
	trackingPlacing = true
	tracking.__tmapKeepShown = true
	local anchor = Minimap or ns.GetCluster()
	if not anchor then
		trackingPlacing = false
		return
	end
	HookTracking(tracking)
	tracking:SetParent(UIParent)
	tracking:ClearAllPoints()
	tracking:SetPoint("CENTER", anchor, "TOPLEFT", 0, 0)
	tracking:SetSize(28, 28)
	tracking:SetFrameStrata("HIGH")
	tracking:SetFrameLevel(64)
	if tracking.Background then
		tracking.Background:ClearAllPoints()
		tracking.Background:SetAllPoints()
		tracking.Background:Show()
	end
	local button = TrackingButton(tracking)
	if button then
		button.__tmapKeepShown = true
		button:SetParent(tracking)
		button:ClearAllPoints()
		button:SetPoint("CENTER")
		button:SetSize(28, 28)
		button:EnableMouse(true)
		if button.SetMouseClickEnabled then
			button:SetMouseClickEnabled(true)
		end
		if button.SetMouseMotionEnabled then
			button:SetMouseMotionEnabled(true)
		end
		if button.SetHitRectInsets then
			button:SetHitRectInsets(0, 0, 0, 0)
		end
		if button.Enable then
			button:Enable()
		end
		-- Do not call button:Show(); MiniMapTrackingButtonMixin:Show(shown)
		-- treats a missing argument as hide.
	end
	tracking:Show()
	trackingPlacing = false
end

local function TexturePathLooksLikeDayNight(value)
	if not value then
		return false
	end
	local name = string.lower(tostring(value))
	return string.find(name, "tod", 1, true)
		or string.find(name, "timeofday", 1, true)
		or string.find(name, "ui-tod", 1, true)
		or string.find(name, "gametime", 1, true)
		or string.find(name, "sunmoon", 1, true)
		or string.find(name, "minimap-sun", 1, true)
		or string.find(name, "daynight", 1, true)
		or string.find(name, "sun", 1, true)
		or string.find(name, "moon", 1, true)
end

local function KillDayNightTexture(tex)
	if not tex then
		return
	end
	pcall(function()
		tex:SetTexture(nil)
	end)
	pcall(function()
		tex:SetAtlas(nil)
	end)
	tex:SetAlpha(0)
	tex:Hide()
	if tex.ClearAllPoints then
		tex:ClearAllPoints()
	end
	if tex.SetParent and UIParent then
		tex:SetParent(UIParent)
	end
	if tex.SetPoint then
		tex:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
	end
	if tex.SetSize then
		tex:SetSize(1, 1)
	end
	if tex.__tmapDayNightKill then
		return
	end
	tex.__tmapDayNightKill = true
	hooksecurefunc(tex, "Show", function(self)
		if ns.IsEnabled() then
			self:Hide()
			self:SetAlpha(0)
		end
	end)
	if tex.SetTexCoord then
		hooksecurefunc(tex, "SetTexCoord", function(self)
			if ns.IsEnabled() then
				self:Hide()
				self:SetAlpha(0)
			end
		end)
	end
	if tex.SetTexture then
		hooksecurefunc(tex, "SetTexture", function(self)
			if ns.IsEnabled() then
				self:Hide()
				self:SetAlpha(0)
			end
		end)
	end
end

local function DescribeRegion(region)
	if not region then
		return "?"
	end
	local name = (region.GetName and region:GetName()) or "(anon)"
	local ot = (region.GetObjectType and region:GetObjectType()) or "?"
	local w = region.GetWidth and region:GetWidth() or 0
	local h = region.GetHeight and region:GetHeight() or 0
	local shown = region.IsShown and region:IsShown()
	local path, atlas = "", ""
	if region.GetTexture then
		local ok, tex = pcall(region.GetTexture, region)
		if ok and tex ~= nil then
			path = tostring(tex)
		end
	end
	if region.GetAtlas then
		local ok, a = pcall(region.GetAtlas, region)
		if ok and a and a ~= "" then
			atlas = tostring(a)
		end
	end
	local pointInfo = ""
	if region.GetNumPoints and region.GetPoint then
		local n = region:GetNumPoints() or 0
		if n > 0 then
			local point, relativeTo, relativePoint, x, y = region:GetPoint(1)
			local relName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or tostring(relativeTo)
			pointInfo = string.format(" %s->%s.%s (%.0f,%.0f)", tostring(point), tostring(relName), tostring(relativePoint), x or 0, y or 0)
		end
	end
	return string.format(
		"%s %s %.0fx%.0f shown=%s tex=%s atlas=%s%s",
		ot,
		tostring(name),
		w,
		h,
		shown and "yes" or "no",
		path ~= "" and path or "-",
		atlas ~= "" and atlas or "-",
		pointInfo
	)
end

local function ShouldSkipFrame(frame)
	local tracking = TrackingFrame()
	local trackingButton = TrackingButton(tracking)
	return frame == ns.pulse
		or frame == ns.header
		or frame == ns.mover
		or frame == CalendarFrame()
		or frame == tracking
		or frame == trackingButton
		or (frame and frame.__gatherMemoryPin)
end

local function IsLikelyDayNightTexture(region)
	if not region or not region.GetObjectType or region:GetObjectType() ~= "Texture" then
		return false
	end
	local name = region.GetName and region:GetName()
	local path, atlas
	if region.GetTexture then
		local ok, tex = pcall(region.GetTexture, region)
		if ok then
			path = tex
		end
	end
	if region.GetAtlas then
		local ok, a = pcall(region.GetAtlas, region)
		if ok then
			atlas = a
		end
	end
	if TexturePathLooksLikeDayNight(name)
		or TexturePathLooksLikeDayNight(path)
		or TexturePathLooksLikeDayNight(atlas)
	then
		return true
	end

	local w = region.GetWidth and region:GetWidth() or 0
	local h = region.GetHeight and region:GetHeight() or 0
	if w < 20 or h < 20 or w > 220 or h > 220 then
		return false
	end
	if math.abs(w - h) > 24 then
		return false
	end
	if not region.IsShown or not region:IsShown() then
		return false
	end
	if not Minimap or not region.GetNumPoints then
		return false
	end
	local n = region:GetNumPoints() or 0
	if n == 0 then
		return true
	end
	for i = 1, n do
		local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
		x = x or 0
		y = y or 0
		if relativeTo == Minimap and point == "CENTER" and relativePoint == "CENTER" and math.abs(x) < 40 and math.abs(y) < 40 then
			return true
		end
	end
	return false
end

local function SweepFrameDeep(frame, depth)
	if not frame or depth > 4 or ShouldSkipFrame(frame) then
		return
	end
	if frame.GetRegions then
		local ok, regions = pcall(function()
			return { frame:GetRegions() }
		end)
		if ok and regions then
			for i = 1, #regions do
				local region = regions[i]
				if IsLikelyDayNightTexture(region) then
					KillDayNightTexture(region)
				end
			end
		end
	end
	if frame.GetChildren then
		local ok, children = pcall(function()
			return { frame:GetChildren() }
		end)
		if ok and children then
			for i = 1, #children do
				local child = children[i]
				if child and not ShouldSkipFrame(child) then
					local name = string.lower(tostring((child.GetName and child:GetName()) or ""))
					local ot = child.GetObjectType and child:GetObjectType()
					if (ot == "Button" or ot == "Frame") and child ~= CalendarFrame() then
						if string.find(name, "tod", 1, true)
							or string.find(name, "sun", 1, true)
							or string.find(name, "moon", 1, true)
							or string.find(name, "daynight", 1, true)
							or string.find(name, "gametime", 1, true)
							or string.find(name, "timeofday", 1, true)
						then
							HideFrame(child)
						end
					end
					SweepFrameDeep(child, depth + 1)
				end
			end
		end
	end
end

function ns.HideDayNightCenter()
	-- Calendar (GameTimeFrame) stays. Kill the orphan sun/moon at map center.
	KillDayNightTexture(_G.GameTimeTexture)
	KillDayNightTexture(_G.MinimapGameTimeTexture)
	KillDayNightTexture(_G.MinimapOverlay)
	KillDayNightTexture(_G.MinimapSunTexture)
	KillDayNightTexture(_G.MinimapDayNightTexture)
	SweepFrameDeep(Minimap, 0)
	SweepFrameDeep(ns.GetCluster(), 0)
	if MinimapCluster and MinimapCluster.MinimapContainer then
		SweepFrameDeep(MinimapCluster.MinimapContainer, 0)
	end
	if not ns.__tmapDayNightUpdateHook and type(GameTimeFrame_OnUpdate) == "function" then
		ns.__tmapDayNightUpdateHook = true
		hooksecurefunc("GameTimeFrame_OnUpdate", function()
			if ns.IsEnabled() then
				KillDayNightTexture(_G.GameTimeTexture)
			end
		end)
	end
	if not ns.__tmapDayNightSweeper and Minimap then
		ns.__tmapDayNightSweeper = CreateFrame("Frame")
		local left = 8
		ns.__tmapDayNightSweeper:SetScript("OnUpdate", function(self, elapsed)
			if not ns.IsEnabled() then
				return
			end
			left = left - elapsed
			SweepFrameDeep(Minimap, 0)
			KillDayNightTexture(_G.GameTimeTexture)
			if left <= 0 then
				self:SetScript("OnUpdate", nil)
			end
		end)
	end
end

function ns.DumpMinimapChrome()
	ns.Print("Minimap chrome dump:")
	local function dumpFrame(label, frame)
		if not frame then
			print("  " .. label .. ": nil")
			return
		end
		print("  --- " .. label .. " ---")
		if frame.GetRegions then
			local ok, regions = pcall(function()
				return { frame:GetRegions() }
			end)
			if ok and regions then
				for i = 1, #regions do
					print("  R" .. i .. ": " .. DescribeRegion(regions[i]))
				end
			end
		end
		if frame.GetChildren then
			local ok, children = pcall(function()
				return { frame:GetChildren() }
			end)
			if ok and children then
				for i = 1, #children do
					local child = children[i]
					print("  C" .. i .. ": " .. DescribeRegion(child))
					if child and child.GetRegions then
						local rok, regions = pcall(function()
							return { child:GetRegions() }
						end)
						if rok and regions then
							for j = 1, math.min(#regions, 8) do
								print("    r" .. j .. ": " .. DescribeRegion(regions[j]))
							end
						end
					end
				end
			end
		end
	end
	dumpFrame("Minimap", Minimap)
	dumpFrame("MinimapCluster", MinimapCluster)
	dumpFrame("GameTimeFrame", CalendarFrame())
	dumpFrame("Tracking", TrackingFrame())
	print("  GameTimeTexture: " .. DescribeRegion(_G.GameTimeTexture))
end

local function ZoneName()
	-- https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit
	-- https://warcraft.wiki.gg/wiki/API_C_Map.GetMapInfo
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
		local mapID = C_Map.GetBestMapForUnit("player")
		if mapID then
			local info = C_Map.GetMapInfo(mapID)
			if info and info.name and info.name ~= "" then
				return info.name
			end
		end
	end
	-- https://warcraft.wiki.gg/wiki/API_GetZoneText
	if GetZoneText then
		return GetZoneText()
	end
	return ""
end

function ns.UpdateHeader()
	if not header or not header.text then
		return
	end
	header.text:SetText(ZoneName())
end

local function CreateHeader(cluster)
	if header then
		return header
	end
	header = CreateFrame("Frame", nil, cluster)
	header:SetHeight(ns.HEADER_HEIGHT)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.text:SetAllPoints()
	header.text:SetJustifyH("CENTER")
	header.text:SetJustifyV("MIDDLE")
	ns.header = header
	return header
end

local function CreateMover(cluster)
	if mover then
		return mover
	end
	mover = CreateFrame("Frame", nil, cluster)
	mover:SetFrameStrata("HIGH")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	local highlight = mover:CreateTexture(nil, "BACKGROUND")
	highlight:SetAllPoints()
	highlight:SetColorTexture(0.2, 0.8, 1, 0.12)
	mover:SetScript("OnDragStart", function()
		if ns.IsLocked() then
			return
		end
		cluster:StartMoving()
	end)
	mover:SetScript("OnDragStop", function()
		cluster:StopMovingOrSizing()
		ns.SavePosition()
	end)
	ns.mover = mover
	return mover
end

function ns.SavePosition()
	local cluster = ns.GetCluster()
	if not cluster then
		return
	end
	local point, _, _, x, y = cluster:GetPoint(1)
	if point then
		TobarisuMapDB.point = point
		TobarisuMapDB.x = x
		TobarisuMapDB.y = y
	end
end

function ns.ApplyPosition()
	local cluster = ns.GetCluster()
	if not cluster then
		return
	end
	cluster:ClearAllPoints()
	cluster:SetPoint(
		TobarisuMapDB.point or "TOPRIGHT",
		UIParent,
		TobarisuMapDB.point or "TOPRIGHT",
		TobarisuMapDB.x or -10,
		TobarisuMapDB.y or -10
	)
end

function ns.ApplySize()
	local size = TobarisuMapDB.size or 200
	if Minimap then
		Minimap:SetSize(size, size)
	end
	local cluster = ns.GetCluster()
	local container = cluster and cluster.MinimapContainer
	if container then
		container:SetSize(size, size)
	end
	if header then
		header:SetWidth(size)
	end
	if mover and Minimap then
		mover:ClearAllPoints()
		mover:SetAllPoints(Minimap)
	end
	if ns.LayoutWidgets then
		ns.LayoutWidgets()
	end
	if ns.PlaceCalendar then
		ns.PlaceCalendar()
	end
	if ns.PlaceTracking then
		ns.PlaceTracking()
	end
end

function ns.ApplySquareMask()
	if not Minimap then
		return
	end
	if Minimap.SetMaskTexture then
		-- https://warcraft.wiki.gg/wiki/UIOBJECT_Minimap
		Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
	end
	if Minimap.SetClipsChildren then
		Minimap:SetClipsChildren(true)
	end
	-- https://warcraft.wiki.gg/wiki/API_Minimap_SetQuestBlobRingScalar
	if Minimap.SetQuestBlobRingScalar then
		Minimap:SetQuestBlobRingScalar(0)
	end
	if Minimap.SetArchBlobRingScalar then
		Minimap:SetArchBlobRingScalar(0)
	end
	if Minimap.SetTaskBlobRingScalar then
		Minimap:SetTaskBlobRingScalar(0)
	end
end

function ns.ApplyVisibility()
	local cluster = ns.GetCluster()
	if not cluster then
		return
	end
	if ns.IsEnabled() then
		cluster:Show()
	else
		cluster:Hide()
	end
	if ns.UpdateMover then
		ns.UpdateMover()
	end
	if ns.UpdatePulseState then
		ns.UpdatePulseState()
	end
end

function ns.UpdateMover()
	if not mover then
		return
	end
	if ns.IsEnabled() and not ns.IsLocked() then
		mover:Show()
	else
		mover:Hide()
	end
end

function ns.SetEnabled(enabled)
	TobarisuMapDB.enabled = enabled and true or false
	ns.ApplyVisibility()
end

function ns.SetLocked(locked)
	TobarisuMapDB.locked = locked and true or false
	ns.UpdateMover()
end

function ns.InitLayout()
	local cluster = ns.GetCluster()
	if not cluster then
		return
	end

	HideChrome()
	ns.ApplySquareMask()
	ns.PlaceCalendar()
	ns.PlaceTracking()
	ns.HideDayNightCenter()

	cluster:SetMovable(true)
	cluster:SetClampedToScreen(true)
	pcall(function()
		if cluster.SetUserPlaced then
			cluster:SetUserPlaced(true)
		end
	end)
	if cluster.SetDontSavePosition then
		cluster:SetDontSavePosition(true)
	end

	local size = TobarisuMapDB.size or 200
	if cluster.MinimapContainer then
		cluster.MinimapContainer:ClearAllPoints()
		cluster.MinimapContainer:SetPoint("CENTER", cluster, "CENTER", 0, -ns.HEADER_HEIGHT / 2)
		cluster.MinimapContainer:SetSize(size, size)
	end
	if Minimap then
		Minimap:ClearAllPoints()
		if cluster.MinimapContainer then
			Minimap:SetPoint("CENTER", cluster.MinimapContainer, "CENTER")
		else
			Minimap:SetPoint("CENTER", cluster, "CENTER", 0, -ns.HEADER_HEIGHT / 2)
		end
		Minimap:SetSize(size, size)
	end

	cluster:SetSize(size, size + ns.HEADER_HEIGHT)

	CreateHeader(cluster)
	header:ClearAllPoints()
	header:SetPoint("BOTTOM", Minimap or cluster, "TOP", 0, 2)
	header:SetWidth(size)

	CreateMover(cluster)
	mover:SetAllPoints(Minimap or cluster)

	ns.ApplyPosition()
	ns.ApplySize()
	ns.UpdateHeader()
	ns.ApplyVisibility()
	ns.UpdateMover()

	if GatherMemory and GatherMemory.RebuildMinimap then
		GatherMemory.RebuildMinimap()
	end

	local zoneFrame = CreateFrame("Frame")
	zoneFrame:RegisterEvent("ZONE_CHANGED")
	zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
	zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	zoneFrame:SetScript("OnEvent", function(_, event)
		ns.UpdateHeader()
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
			ns.ApplySquareMask()
			ns.ApplySize()
			ns.HideDayNightCenter()
			if GatherMemory and GatherMemory.RebuildMinimap then
				GatherMemory.RebuildMinimap()
			end
		end
	end)
end
