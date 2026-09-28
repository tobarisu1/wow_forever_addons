local _, ns = ...

local PAD = 2
local DRAG_SLOP = 3

local EDGES = {
	N = true,
	E = true,
	S = true,
	W = true,
}

local EDGE_LIST = { "N", "E", "S", "W" }

local CORNERS = {
	NE = { edge = "N", bias = 1 },
	SE = { edge = "S", bias = 1 },
	SW = { edge = "S", bias = -1 },
	NW = { edge = "N", bias = -1 },
}

local widgets = {}
local pending = {}
local ready = false

local function Square()
	return ns.GetCluster() or Minimap
end

local function NormalizeRequest(edge)
	if type(edge) ~= "string" then
		return "W", nil
	end
	edge = string.upper(edge)
	local corner = CORNERS[edge]
	if corner then
		return corner.edge, corner.bias
	end
	if EDGES[edge] then
		return edge, nil
	end
	return "W", nil
end

local function SavedPlace(id)
	if type(TobarisuMapDB) ~= "table" or type(TobarisuMapDB.widgets) ~= "table" then
		return nil
	end
	local row = TobarisuMapDB.widgets[id]
	if type(row) ~= "table" then
		return nil
	end
	local edge = type(row.edge) == "string" and string.upper(row.edge) or nil
	local along = tonumber(row.along)
	if not edge or not EDGES[edge] or not along then
		return nil
	end
	return edge, along
end

local function SavePlace(widget)
	if type(ns.InitDB) == "function" then
		ns.InitDB()
	end
	if type(TobarisuMapDB) ~= "table" then
		return
	end
	if type(TobarisuMapDB.widgets) ~= "table" then
		TobarisuMapDB.widgets = {}
	end
	TobarisuMapDB.widgets[widget.id] = {
		edge = widget.edge,
		along = widget.along or 0,
	}
end

local function HalfSizes(square)
	local left, right = square:GetLeft(), square:GetRight()
	local bottom, top = square:GetBottom(), square:GetTop()
	if not left or not right or not bottom or not top then
		return nil
	end
	return (right - left) / 2, (top - bottom) / 2
end

local function ClampAlong(edge, along, widgetSize, halfW, halfH)
	local limit
	if edge == "N" or edge == "S" then
		limit = halfW - widgetSize / 2 - PAD
	else
		limit = halfH - widgetSize / 2 - PAD
	end
	if not limit or limit < 0 then
		limit = 0
	end
	if along > limit then
		along = limit
	elseif along < -limit then
		along = -limit
	end
	return math.floor(along + 0.5)
end

local function Place(square, widget)
	local frame = widget.frame
	if not frame or not square then
		return
	end
	local halfW, halfH = HalfSizes(square)
	if not halfW then
		return
	end
	local along = ClampAlong(widget.edge, widget.along or 0, widget.size, halfW, halfH)
	widget.along = along
	frame:ClearAllPoints()
	frame:SetParent(square)
	frame:SetSize(widget.size, widget.size)
	-- Center on the edge so the button straddles the square border.
	if widget.edge == "N" then
		frame:SetPoint("CENTER", square, "TOP", along, 0)
	elseif widget.edge == "S" then
		frame:SetPoint("CENTER", square, "BOTTOM", along, 0)
	elseif widget.edge == "E" then
		frame:SetPoint("CENTER", square, "RIGHT", 0, along)
	else
		frame:SetPoint("CENTER", square, "LEFT", 0, along)
	end
	local level = 10
	if Minimap and Minimap.GetFrameLevel then
		level = Minimap:GetFrameLevel() + 20
	end
	frame:SetFrameLevel(level)
	frame:Show()
end

local function NearestPlace(square, widgetSize)
	local scale = square:GetEffectiveScale()
	if not scale or scale == 0 then
		return nil
	end
	local cursorX, cursorY = GetCursorPosition()
	cursorX, cursorY = cursorX / scale, cursorY / scale
	local left, right = square:GetLeft(), square:GetRight()
	local bottom, top = square:GetBottom(), square:GetTop()
	if not left or not right or not bottom or not top then
		return nil
	end
	local halfW = (right - left) / 2
	local halfH = (top - bottom) / 2
	if halfW <= 0 or halfH <= 0 then
		return nil
	end
	local dx = cursorX - (left + right) / 2
	local dy = cursorY - (bottom + top) / 2
	local edge = "W"
	local along = dy
	local best = dx + halfW
	local insetR = halfW - dx
	if insetR < best then
		best = insetR
		edge = "E"
		along = dy
	end
	local insetT = halfH - dy
	if insetT < best then
		best = insetT
		edge = "N"
		along = dx
	end
	local insetB = dy + halfH
	if insetB < best then
		edge = "S"
		along = dx
	end
	return edge, ClampAlong(edge, along, widgetSize, halfW, halfH)
end

local function LayoutEdge(square, edge, list)
	local halfW, halfH = HalfSizes(square)
	if not halfW then
		return
	end
	local defaults = {}
	for i = 1, #list do
		local widget = list[i]
		if widget.custom then
			Place(square, widget)
		else
			defaults[#defaults + 1] = widget
		end
	end
	table.sort(defaults, function(a, b)
		return a.id < b.id
	end)
	local total = 0
	for i = 1, #defaults do
		total = total + defaults[i].size
		if i > 1 then
			total = total + ns.WIDGET_GAP
		end
	end
	local cursor = -total / 2
	for i = 1, #defaults do
		local widget = defaults[i]
		widget.along = cursor + widget.size / 2
		if widget.cornerBias then
			local limit
			if edge == "N" or edge == "S" then
				limit = halfW - widget.size / 2 - PAD
			else
				limit = halfH - widget.size / 2 - PAD
			end
			if not limit or limit < 0 then
				limit = 0
			end
			widget.along = widget.cornerBias * limit
		end
		Place(square, widget)
		cursor = cursor + widget.size + ns.WIDGET_GAP
	end
end

function ns.LayoutWidgets()
	local square = Square()
	if not ready or not square then
		return
	end
	local grouped = {
		N = {},
		E = {},
		S = {},
		W = {},
	}
	for _, widget in pairs(widgets) do
		local edge = widget.edge
		if not grouped[edge] then
			edge = "W"
			widget.edge = edge
		end
		local list = grouped[edge]
		list[#list + 1] = widget
	end
	for i = 1, #EDGE_LIST do
		local edge = EDGE_LIST[i]
		LayoutEdge(square, edge, grouped[edge])
	end
end

local function AttachDrag(widget)
	local frame = widget.frame
	frame.tmapWidget = widget
	if frame.tmapDrag then
		return
	end
	frame.tmapDrag = true
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")

	local originalClick = frame:GetScript("OnClick")
	frame:SetScript("OnClick", function(self, button)
		local current = self.tmapWidget
		if current and current.moved then
			current.moved = false
			return
		end
		if originalClick then
			originalClick(self, button)
		end
	end)

	frame:SetScript("OnDragStart", function(self)
		local current = self.tmapWidget
		if not current then
			return
		end
		current.dragging = true
		current.moved = false
		current.dragEdge = current.edge
		current.dragAlong = current.along or 0
		self:SetScript("OnUpdate", function(btn)
			local live = btn.tmapWidget
			local square = Square()
			if not live or not square then
				return
			end
			local edge, along = NearestPlace(square, live.size)
			if not edge then
				return
			end
			if edge ~= live.dragEdge or math.abs(along - (live.dragAlong or 0)) > DRAG_SLOP then
				live.moved = true
			end
			live.edge = edge
			live.along = along
			live.custom = true
			live.cornerBias = nil
			Place(square, live)
		end)
	end)

	frame:SetScript("OnDragStop", function(self)
		local current = self.tmapWidget
		self:SetScript("OnUpdate", nil)
		if not current then
			return
		end
		current.dragging = false
		SavePlace(current)
		if current.moved and C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				current.moved = false
			end)
		end
	end)
end

local function StoreWidget(id, opts)
	opts = opts or {}
	local existing = widgets[id]
	local frame = opts.frame or (existing and existing.frame)
	if not frame then
		local size = opts.size or 24
		frame = CreateFrame("Frame", nil, Square() or UIParent)
		frame:SetSize(size, size)
	end
	local size = opts.size or (existing and existing.size) or 24
	local edge, cornerBias = NormalizeRequest(opts.edge)
	local along = 0
	local custom = false
	local savedEdge, savedAlong = SavedPlace(id)
	if savedEdge then
		edge = savedEdge
		along = savedAlong
		custom = true
		cornerBias = nil
	end
	local widget = {
		id = id,
		edge = edge,
		along = along,
		size = size,
		frame = frame,
		custom = custom,
		cornerBias = cornerBias,
	}
	widgets[id] = widget
	AttachDrag(widget)
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
		local frame = opts and opts.frame
		if not frame then
			local size = (opts and opts.size) or 24
			frame = CreateFrame("Frame", nil, UIParent)
			frame:SetSize(size, size)
		end
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
