local _, ns = ...

if CreateFromMixins and MapCanvasPinMixin then
	GatherMemoryPinMixin = CreateFromMixins(MapCanvasPinMixin)
else
	GatherMemoryPinMixin = {}
end

function GatherMemoryPinMixin:OnLoad()
	self:SetSize(ns.WORLDMAP_PIN_SIZE, ns.WORLDMAP_PIN_SIZE)
	if self.SetIgnoreGlobalPinScale then
		self:SetIgnoreGlobalPinScale(true)
	end
	if self.UseFrameLevelType then
		self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
	end
	if self.SetScalingLimits then
		self:SetScalingLimits(1, 1.0, 1.0)
	end
	self:EnableMouse(true)
	if self.SetMouseMotionEnabled then
		self:SetMouseMotionEnabled(true)
	end
	if self.SetMouseClickEnabled then
		self:SetMouseClickEnabled(false)
	end
end

function GatherMemoryPinMixin:OnAcquired(node)
	self.node = node
	self:SetSize(ns.WORLDMAP_PIN_SIZE, ns.WORLDMAP_PIN_SIZE)
	if self.SetPosition then
		self:SetPosition(node.x, node.y)
	end
	if self.Texture then
		self.Texture:SetTexture(ns.GetNodeIcon(node.name, node.kind))
		self.Texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	self:Show()
end

function GatherMemoryPinMixin:OnReleased()
	self.node = nil
end

function GatherMemoryPinMixin:OnMouseEnter()
	ns.ShowNodeTooltip(self, self.node)
end

function GatherMemoryPinMixin:OnMouseLeave()
	ns.HideNodeTooltip()
end

local provider

local function CreateProvider()
	if not MapCanvasDataProviderMixin or not CreateFromMixins then
		return nil
	end
	local dataProvider = CreateFromMixins(MapCanvasDataProviderMixin)

	function dataProvider:RemoveAllData()
		if self.GetMap then
			self:GetMap():RemoveAllPinsByTemplate("GatherMemoryPinTemplate")
		end
	end

	function dataProvider:RefreshAllData()
		self:RemoveAllData()
		if ns.GetSetting("showWorldMap") == false then
			return
		end
		local map = self:GetMap()
		if not map or not map.GetMapID then
			return
		end
		local mapID = map:GetMapID()
		ns.ForEachNode(function(node)
			if not ns.IsKindShown(node.kind) then
				return
			end
			local x, y
			pcall(function()
				x, y = ns.GetNodeMapPosition(node, mapID)
			end)
			if not x or not y then
				return
			end
			map:AcquirePin("GatherMemoryPinTemplate", {
				name = node.name,
				kind = node.kind,
				x = x,
				y = y,
			})
		end)
	end

	return dataProvider
end

function ns.RefreshWorldMap()
	if provider then
		provider:RefreshAllData()
	end
end

function ns.InitWorldMap()
	if ns.worldMapReady then
		return
	end
	if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
		return
	end
	if MapCanvasPinMixin and Mixin and not GatherMemoryPinMixin.SetPosition then
		Mixin(GatherMemoryPinMixin, MapCanvasPinMixin)
	end
	provider = CreateProvider()
	if not provider then
		return
	end
	WorldMapFrame:AddDataProvider(provider)
	ns.worldMapProvider = provider
	ns.worldMapReady = true
end

local retry = CreateFrame("Frame")
retry:RegisterEvent("ADDON_LOADED")
retry:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_WorldMap" or WorldMapFrame then
		ns.InitWorldMap()
	end
end)
