local _, ns = ...

local EDGES = {
	N = true,
	NE = true,
	E = true,
	SE = true,
	S = true,
	SW = true,
	W = true,
	NW = true,
}

local EDGE_LIST = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local widgets = {}
local pending = {}
local ready = false

local function WidgetParent()
	return ns.GetCluster() or UIParent
end

local function NormalizeEdge(edge)
	if type(edge) ~= "string" then
		return "E"
	end
	edge = string.upper(edge)
	if EDGES[edge] then
		return edge
	end
	return "E"
end

local function MakeHolder(opts)
	if opts and opts.frame then
		return opts.frame
	end
	local size = (opts and opts.size) or 24
	local holder = CreateFrame("Frame", nil, WidgetParent())
	holder:SetSize(size, size)
	return holder
end

local function PlaceOnEdge(frame, edge, alongOffset, size)
	local gap = ns.WIDGET_GAP
	local map = Minimap or ns.GetCluster()
	frame:ClearAllPoints()
	frame:SetParent(WidgetParent())
	if edge == "N" then
		frame:SetPoint("BOTTOM", map, "TOP", alongOffset, gap + ns.HEADER_HEIGHT)
	elseif edge == "S" then
		frame:SetPoint("TOP", map, "BOTTOM", alongOffset, -gap)
	elseif edge == "E" then
		frame:SetPoint("LEFT", map, "RIGHT", gap, alongOffset)
	elseif edge == "W" then
		frame:SetPoint("RIGHT", map, "LEFT", -gap, alongOffset)
	elseif edge == "NE" then
		frame:SetPoint("BOTTOMLEFT", map, "TOPRIGHT", gap, gap)
	elseif edge == "SE" then
		frame:SetPoint("TOPLEFT", map, "BOTTOMRIGHT", gap, -gap)
	elseif edge == "SW" then
		frame:SetPoint("TOPRIGHT", map, "BOTTOMLEFT", -gap, -gap)
	elseif edge == "NW" then
		frame:SetPoint("BOTTOMRIGHT", map, "TOPLEFT", -gap, gap)
	end
	if size then
		frame:SetSize(size, size)
	end
end

function ns.LayoutWidgets()
	if not ready or not Minimap then
		return
	end
	for i = 1, #EDGE_LIST do
		local edge = EDGE_LIST[i]
		local list = {}
		for _, widget in pairs(widgets) do
			if widget.edge == edge then
				list[#list + 1] = widget
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		local total = 0
		for j = 1, #list do
			total = total + list[j].size
			if j > 1 then
				total = total + ns.WIDGET_GAP
			end
		end
		local cursor = -total / 2
		for j = 1, #list do
			local widget = list[j]
			local along = 0
			if edge == "N" or edge == "S" or edge == "E" or edge == "W" then
				along = cursor + widget.size / 2
			end
			PlaceOnEdge(widget.frame, edge, along, widget.size)
			widget.frame:Show()
			cursor = cursor + widget.size + ns.WIDGET_GAP
		end
	end
end

local function StoreWidget(id, opts)
	opts = opts or {}
	local existing = widgets[id]
	local frame = (opts.frame) or (existing and existing.frame) or MakeHolder(opts)
	local size = opts.size or (existing and existing.size) or 24
	widgets[id] = {
		id = id,
		edge = NormalizeEdge(opts.edge),
		size = size,
		frame = frame,
	}
	if ready then
		ns.LayoutWidgets()
	end
	return frame
end

function TobarisuMap.RegisterWidget(id, opts)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if not ready then
		pending[#pending + 1] = { id = id, opts = opts }
		local frame = (opts and opts.frame) or MakeHolder(opts)
		pending[#pending].frame = frame
		return frame
	end
	return StoreWidget(id, opts)
end

function TobarisuMap.UnregisterWidget(id)
	if type(id) ~= "string" then
		return
	end
	if not ready then
		for i = #pending, 1, -1 do
			if pending[i].id == id then
				if pending[i].frame then
					pending[i].frame:Hide()
				end
				table.remove(pending, i)
			end
		end
		return
	end
	local widget = widgets[id]
	if not widget then
		return
	end
	widgets[id] = nil
	if widget.frame then
		widget.frame:Hide()
	end
	ns.LayoutWidgets()
end

function ns.InitWidgets()
	ready = true
	for i = 1, #pending do
		local item = pending[i]
		local opts = item.opts or {}
		opts.frame = item.frame or opts.frame
		StoreWidget(item.id, opts)
	end
	for i = 1, #pending do
		pending[i] = nil
	end
	ns.LayoutWidgets()
end
