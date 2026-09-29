local _, ns = ...

local POOL = 20
local SCROLL_SPEED = 48
local INCOMING_LIFE = 1.7
local REACTIVE_LIFE = 2.1
local FADE_TIME = 0.4
local POP_TIME = 0.2
local INCOMING_X = -170
local INCOMING_Y = 40
local REACTIVE_X = 0
local REACTIVE_Y = 150

local host
local pool = {}
local active = {}

local function ApplyLineFont(fs, size)
	local flags = ns.FontFlags()
	if fs:SetFont(ns.FontFile(), size, flags) then
		return
	end
	fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
end

local function Place(line)
	local y = line.y
	if line.kind == "incoming" then
		y = line.y + line.age * SCROLL_SPEED
	end
	line.fs:ClearAllPoints()
	line.fs:SetPoint("CENTER", UIParent, "CENTER", line.x, y)
end

local function Raise(kind, spacing)
	for i = 1, #active do
		if active[i].kind == kind then
			active[i].y = active[i].y + spacing
		end
	end
end

local function Acquire()
	for i = 1, #pool do
		if not pool[i].busy then
			return pool[i]
		end
	end
	local oldest = active[1]
	if not oldest then
		return nil
	end
	oldest.fs:Hide()
	oldest.busy = false
	table.remove(active, 1)
	return oldest
end

function ns.RestyleActive()
	for i = 1, #active do
		local line = active[i]
		line.size = ns.FontSize(line.large)
		ApplyLineFont(line.fs, line.size)
	end
end

function ns.ShowCombatText(kind, r, g, b, large, text, secretArg)
	if not host or not CombatTextMasterDB or not CombatTextMasterDB.enabled then
		return
	end
	if type(text) ~= "string" then
		return
	end
	local line = Acquire()
	if not line then
		return
	end
	line.busy = true
	line.kind = kind
	line.large = large and true or false
	line.age = 0
	line.popDone = false
	line.size = ns.FontSize(line.large)
	if kind == "reactive" then
		line.x = REACTIVE_X
		line.y = REACTIVE_Y
		line.life = REACTIVE_LIFE
		Raise("reactive", line.size + 6)
	else
		line.x = INCOMING_X
		line.y = INCOMING_Y
		line.life = INCOMING_LIFE
		Raise("incoming", line.size + 4)
	end
	local fs = line.fs
	ApplyLineFont(fs, line.size)
	fs:SetTextColor(r, g, b)
	fs:SetAlpha(1)
	if secretArg ~= nil then
		fs:SetFormattedText(text, secretArg)
	else
		fs:SetText(text)
	end
	fs:Show()
	Place(line)
	active[#active + 1] = line
end

local function OnUpdate(_, elapsed)
	local i = 1
	while i <= #active do
		local line = active[i]
		line.age = line.age + elapsed
		if line.age >= line.life then
			line.fs:Hide()
			line.busy = false
			table.remove(active, i)
		else
			local alpha = 1
			local fadeStart = line.life - FADE_TIME
			if line.age > fadeStart then
				alpha = 1 - (line.age - fadeStart) / FADE_TIME
			end
			line.fs:SetAlpha(alpha)
			if line.large and line.age < POP_TIME then
				local extra = 1 + 0.4 * (1 - line.age / POP_TIME)
				pcall(line.fs.SetTextHeight, line.fs, line.size * extra)
			elseif line.large and not line.popDone then
				pcall(line.fs.SetTextHeight, line.fs, line.size)
				line.popDone = true
			end
			Place(line)
			i = i + 1
		end
	end
end

function ns.InitDisplay()
	if host then
		return
	end
	host = CreateFrame("Frame", nil, UIParent)
	host:SetAllPoints(UIParent)
	host:EnableMouse(false)
	host:SetFrameStrata("MEDIUM")
	for i = 1, POOL do
		local fs = host:CreateFontString(nil, "OVERLAY")
		fs:Hide()
		pool[i] = { fs = fs, busy = false }
	end
	host:SetScript("OnUpdate", OnUpdate)
end

ns.InitDisplay()
