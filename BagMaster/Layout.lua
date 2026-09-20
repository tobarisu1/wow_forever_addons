local _, ns = ...

local headers = {}
local hooked = false

local function GetCombinedBags()
	return ContainerFrameCombinedBags
end

local function GetItemSize(container)
	local width, height = 37, 37
	if container.itemButtonPool and C_XMLUtil and C_XMLUtil.GetTemplateInfo then
		local info = C_XMLUtil.GetTemplateInfo(container.itemButtonPool:GetTemplate())
		if info and info.width and info.height then
			width = info.width
			height = info.height
		end
	end
	if container.EnumerateValidItems then
		for _, itemButton in container:EnumerateValidItems() do
			local buttonWidth = itemButton:GetWidth()
			local buttonHeight = itemButton:GetHeight()
			if buttonWidth and buttonWidth > 0 then
				width = buttonWidth
			end
			if buttonHeight and buttonHeight > 0 then
				height = buttonHeight
			end
			break
		end
	end
	return width, height
end

local function GetColumns(container)
	if container.GetColumns then
		return container:GetColumns()
	end
	return ns.COLUMNS
end

local function SortBagButtons(a, b)
	if a.IsExtended and b.IsExtended then
		local extendedA, extendedB = a:IsExtended(), b:IsExtended()
		if extendedA ~= extendedB then
			return not extendedA
		end
	end
	return a:GetID() > b:GetID()
end

local function GroupItemsByBag(container)
	local byBag = {}
	local bagIDs = {}
	if not container.EnumerateValidItems then
		return bagIDs, byBag
	end
	for _, itemButton in container:EnumerateValidItems() do
		local bagID = itemButton:GetBagID()
		if bagID then
			if not byBag[bagID] then
				byBag[bagID] = {}
				bagIDs[#bagIDs + 1] = bagID
			end
			byBag[bagID][#byBag[bagID] + 1] = itemButton
		end
	end
	table.sort(bagIDs, function(a, b)
		return a > b
	end)
	for i = 1, #bagIDs do
		table.sort(byBag[bagIDs[i]], SortBagButtons)
	end
	return bagIDs, byBag
end

local function GridHeight(slotCount, itemHeight, columns)
	if slotCount <= 0 then
		return 0
	end
	local rows = math.ceil(slotCount / (columns or ns.COLUMNS))
	return (rows * itemHeight) + ((rows - 1) * ns.ITEM_SPACING_Y)
end

-- FontString ellipsis is unreliable here; cut the string ourselves.
local function TruncateName(name)
	local maxLen = ns.HEADER_NAME_MAX or 16
	if not name or name == "" then
		return name
	end
	local len = (strlenutf8 and strlenutf8(name)) or string.len(name)
	if len <= maxLen then
		return name
	end
	if string.utf8sub then
		return string.utf8sub(name, 1, maxLen - 1) .. "…"
	end
	return string.sub(name, 1, maxLen - 1) .. "…"
end

local function GetBagName(bagID)
	local name = C_Container.GetBagName(bagID)
	if name and name ~= "" then
		return TruncateName(name)
	end
	if bagID == 0 and BAG_NAME_BACKPACK then
		return TruncateName(BAG_NAME_BACKPACK)
	end
	return TruncateName("Bag " .. tostring(bagID))
end

local function GetBagIcon(bagID)
	if bagID and bagID > 0 and C_Container.ContainerIDToInventoryID and GetInventoryItemTexture then
		local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
		if inventoryID then
			local texture = GetInventoryItemTexture("player", inventoryID)
			if texture then
				return texture
			end
		end
	end
	return "Interface/Icons/Inv_misc_bag_08"
end

local function AcquireHeader(container, index)
	local header = headers[index]
	if header then
		header:SetParent(container)
		header:Show()
		return header
	end
	header = CreateFrame("Frame", nil, container)
	header:SetHeight(ns.HEADER_HEIGHT)
	header:EnableMouse(false)
	header.icon = header:CreateTexture(nil, "ARTWORK")
	header.icon:SetSize(14, 14)
	header.icon:SetPoint("LEFT", 0, 0)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.text:SetPoint("LEFT", header.icon, "RIGHT", 4, 0)
	header.text:SetJustifyH("LEFT")
	header.text:SetJustifyV("MIDDLE")
	header.text:SetTextColor(0.75, 0.75, 0.75)
	header.line = header:CreateTexture(nil, "ARTWORK")
	header.line:SetColorTexture(1, 1, 1, 0.12)
	header.line:SetHeight(1)
	header.line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", ns.HEADER_TEXT_INSET or 18, 0)
	header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headers[index] = header
	return header
end

function ns.HideHeaders()
	for i = 1, #headers do
		headers[i]:Hide()
	end
end

local function PlaceHeader(header, relativeTo, yOffset, width, bagID)
	header:ClearAllPoints()
	header:SetSize(width, ns.HEADER_HEIGHT)
	header:SetPoint("BOTTOMRIGHT", relativeTo, "TOPRIGHT", 0, yOffset)
	header.icon:SetTexture(GetBagIcon(bagID))
	header.text:SetText(GetBagName(bagID))
	header:Show()
end

local function LayoutSections(container)
	if not ns.IsEnabled() then
		ns.HideHeaders()
		return
	end
	if not container or not container.IsCombinedBagContainer or not container:IsCombinedBagContainer() then
		return
	end

	local bagIDs, byBag = GroupItemsByBag(container)
	if #bagIDs == 0 then
		ns.HideHeaders()
		return
	end

	local itemWidth, itemHeight = GetItemSize(container)
	local columns = GetColumns(container)
	local gridWidth = (columns * itemWidth) + ((columns - 1) * ns.ITEM_SPACING_X)
	local layout = AnchorUtil.CreateGridLayout(
		GridLayoutMixin.Direction.BottomRightToTopLeft,
		columns,
		ns.ITEM_SPACING_X,
		ns.ITEM_SPACING_Y
	)
	local baseAnchor = container:GetInitialItemAnchor()
	local point, relativeTo, relativePoint, baseX, baseY = baseAnchor:Get()
	local offsetY = 0
	local headerIndex = 0

	for i = 1, #bagIDs do
		local bagID = bagIDs[i]
		local buttons = byBag[bagID]
		local gridH = GridHeight(#buttons, itemHeight, columns)
		local sectionAnchor = AnchorUtil.CreateAnchor(point, relativeTo, relativePoint, baseX, baseY + offsetY)
		AnchorUtil.GridLayout(buttons, sectionAnchor, layout)

		headerIndex = headerIndex + 1
		local header = AcquireHeader(container, headerIndex)
		local headerY = baseY + offsetY + gridH + ns.HEADER_GAP
		PlaceHeader(header, relativeTo, headerY, gridWidth, bagID)

		offsetY = offsetY + gridH + ns.HEADER_GAP + ns.HEADER_HEIGHT + ns.SECTION_GAP
	end

	for i = headerIndex + 1, #headers do
		headers[i]:Hide()
	end

	if container.LayoutAddSlots then
		container:LayoutAddSlots()
	end
end

local function SectionContentHeight(container)
	local _, itemHeight = GetItemSize(container)
	local columns = GetColumns(container)
	local bagIDs, byBag = GroupItemsByBag(container)
	if #bagIDs == 0 then
		return 0
	end
	local height = 0
	for i = 1, #bagIDs do
		if i > 1 then
			height = height + ns.SECTION_GAP
		end
		height = height + GridHeight(#byBag[bagIDs[i]], itemHeight, columns)
		height = height + ns.HEADER_GAP + ns.HEADER_HEIGHT
	end
	return height
end

local function ApplyFrameHeight(container)
	if not ns.IsEnabled() then
		return
	end
	if not container or not container.IsCombinedBagContainer or not container:IsCombinedBagContainer() then
		return
	end
	local contentHeight = SectionContentHeight(container)
	if contentHeight <= 0 then
		return
	end
	local padding = 0
	if container.GetPaddingHeight then
		padding = container:GetPaddingHeight()
	end
	local extra = 0
	if container.CalculateExtraHeight then
		extra = container:CalculateExtraHeight()
	end
	container:SetHeight(contentHeight + padding + extra)
end

function ns.RefreshBags()
	local container = GetCombinedBags()
	if not container or not container.IsShown or not container:IsShown() then
		if not ns.IsEnabled() then
			ns.HideHeaders()
		end
		return
	end
	if container.UpdateItemSlots then
		container:UpdateItemSlots()
	end
	if container.UpdateFrameSize then
		container:UpdateFrameSize()
	end
	if container.UpdateItemLayout then
		container:UpdateItemLayout()
	end
	if UpdateContainerFrameAnchors then
		UpdateContainerFrameAnchors()
	end
	ns.ApplyBagScale()
end

function ns.ApplyBagScale()
	if not ns.IsEnabled() then
		return
	end
	local container = GetCombinedBags()
	if not container or not container:IsShown() then
		return
	end
	container:SetScale(ns.BAG_SCALE or 1.3)
end

function ns.InitLayout()
	if hooked then
		return true
	end
	local container = GetCombinedBags()
	if not container then
		return false
	end
	hooked = true
	hooksecurefunc(container, "UpdateItemLayout", LayoutSections)
	hooksecurefunc(container, "UpdateFrameSize", ApplyFrameHeight)
	-- Blizzard's UpdateContainerFrameAnchors resets scale every open; re-apply after it.
	if UpdateContainerFrameAnchors then
		hooksecurefunc("UpdateContainerFrameAnchors", ns.ApplyBagScale)
	end
	return true
end
