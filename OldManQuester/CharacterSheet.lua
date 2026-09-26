local _, ns = ...

-- The old character window: a 384x512 sheet on Blizzard's character frame,
-- drawn a little larger so the attribute lines sit inside the stat boxes.
-- Portrait and name up top, slots down the sides, weapons along the bottom,
-- the model in the middle, attribute and attack boxes, resistances, and
-- tabs along the foot. The modern chrome and side panel are faded. The
-- frame is then scaled with the rest of OldManQuester so an ultrawide
-- client gets the same enlargement as the quest and gossip windows.

local BASE_W, BASE_H = 384, 512
local GROW = 1.2
local function U(n)
	return n * GROW
end
local WIDTH, HEIGHT = U(BASE_W), U(BASE_H)
local SLOT_GAP = 4
local ART = "Interface\\PaperDollInfoFrame\\"
local BUTTONS = "Interface\\Buttons\\"

local LEFT_SLOTS = {
	"CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
	"CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
}
local RIGHT_SLOTS = {
	"CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
	"CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
}
local WEAPON_SLOTS = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }

local RESISTANCES = {
	{ id = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
	{ id = 2, coords = { 0, 1, 0, 0.11328125 } },
	{ id = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
	{ id = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
	{ id = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}

local BOX_TOP = { 0, 0.8984375, 0, 0.125 }
local BOX_MID = { 0, 0.8984375, 0.125, 0.1953125 }
local BOX_BOT = { 0, 0.8984375, 0.484375, 0.609375 }
local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
local TAB_LABELS = {
	PaperDollFrame = CHARACTER or "Character",
	ReputationFrame = REPUTATION or "Reputation",
	TokenFrame = CURRENCY or "Currency",
	PVPRankFrame = "PvP",
	SkillsFrame = SKILLS or "Skills",
	StatisticsFrame = "Stats",
}
local INNER_BORDERS = {
	"PaperDollInnerBorderTopLeft", "PaperDollInnerBorderTopRight",
	"PaperDollInnerBorderBottomLeft", "PaperDollInnerBorderBottomRight",
	"PaperDollInnerBorderLeft", "PaperDollInnerBorderRight",
	"PaperDollInnerBorderTop", "PaperDollInnerBorderBottom", "PaperDollInnerBorderBottom2",
}
local MODEL_BACKGROUNDS = {
	"BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay",
}

local active = false
local built = false
local hooked = false
local reported = false
local laying = false
local sheet = {}
local placed = {}
local faded = {}
local quieted = {}
local origScale, origWidth, origHeight
local savedCVar

local function Number(value)
	if value == nil or (issecretvalue and issecretvalue(value)) then
		return 0
	end
	return value
end

local function Fade(region)
	if not region or not region.SetAlpha or not region.GetAlpha then
		return
	end
	if faded[region] == nil then
		faded[region] = region:GetAlpha()
	end
	region:SetAlpha(0)
end

local function Remember(region)
	if not region or placed[region] or not region.GetNumPoints then
		return
	end
	local points = {}
	for i = 1, region:GetNumPoints() do
		points[i] = { region:GetPoint(i) }
	end
	placed[region] = {
		points = points,
		width = region:GetWidth(),
		height = region:GetHeight(),
	}
end

local function RememberFrame(frame)
	if origWidth or not frame then
		return
	end
	origScale = frame:GetScale() or 1
	origWidth = frame:GetWidth()
	origHeight = frame:GetHeight()
end

local function Art(texture, path)
	local ok = texture:SetTexture(path)
	return ok ~= false
end

local function Piece(parent, path, w, h, x, y, layer, sub)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
	Art(tex, path)
	tex:SetSize(U(w), U(h))
	tex:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(x), U(y))
	return tex
end

local function LevelLine()
	local level = UnitLevel("player")
	if issecretvalue and issecretvalue(level) then
		level = ""
	else
		level = tostring(level or "")
	end
	local race = UnitRace("player") or ""
	local class = UnitClass("player") or ""
	return string.format("%s %s %s %s", LEVEL or "Level", level, race, class)
end

local function Buffed(base, pos, neg)
	base, pos, neg = Number(base), Number(pos), Number(neg)
	local total = base + pos + neg
	if pos == 0 and neg == 0 then
		return WHITE .. total .. "|r", nil
	end
	local color = WHITE
	if pos > 0 and neg == 0 then
		color = GREEN
	elseif neg < 0 and pos == 0 then
		color = RED
	end
	local detail = string.format("%d (%d base", total, base)
	if pos > 0 then
		detail = detail .. string.format(" %s+%d|r", GREEN, pos)
	end
	if neg < 0 then
		detail = detail .. string.format(" %s%d|r", RED, neg)
	end
	return color .. total .. "|r", detail .. ")"
end

-- Same inset as the strength column: those digits end 5px inside the
-- 115-wide box. The melee box starts at x=115, so its digits end at 225.
-- One anchor only, and no explicit size, so the font stays GameFontHighlightSmall.
local RIGHT_NUMBER_X = 225

local function StatRow(parent, label, anchor, relPoint, x, y, valueX, absX)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(U(104), U(13))
	row:SetPoint("TOPLEFT", anchor, relPoint, U(x), U(y))
	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetText(label)
	row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.value:SetJustifyH("RIGHT")
	row.value:SetWordWrap(false)
	if valueX then
		row.value:SetPoint("RIGHT", row, "RIGHT", U(valueX - (absX + 104)), 0)
	else
		row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	end
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if not self.tip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tip, 1, 1, 1)
		if self.tip2 then
			GameTooltip:AddLine(self.tip2, nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return row
end

local function StatBox(parent, x, y, middleHeight)
	local function Slice(coords, height, anchor, relPoint, dx, dy)
		local tex = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
		Art(tex, ART .. "UI-Character-StatBackground")
		tex:SetSize(U(115), U(height))
		tex:SetTexCoord(unpack(coords))
		tex:SetPoint("TOPLEFT", anchor, relPoint, U(dx), U(dy))
		return tex
	end
	local top = Slice(BOX_TOP, 16, parent, "TOPLEFT", x, y)
	local middle = Slice(BOX_MID, middleHeight, top, "BOTTOMLEFT", 0, 0)
	Slice(BOX_BOT, 16, middle, "BOTTOMLEFT", 0, 0)
	return top
end

local function SheetActor(scene)
	local actor
	if scene.GetPlayerActor then
		actor = scene:GetPlayerActor()
	end
	if not actor and scene.GetActorByTag then
		actor = scene:GetActorByTag("player")
	end
	if not actor and type(scene.tagToActor) == "table" then
		actor = select(2, next(scene.tagToActor))
	end
	if actor and actor.GetYaw and actor.SetYaw then
		return actor
	end
end

local spinner = CreateFrame("Frame")
spinner:Hide()
spinner:SetScript("OnUpdate", function(self, elapsed)
	local scene = CharacterModelScene
	if not scene or not scene:IsVisible() then
		self:Hide()
		return
	end
	local step = self.turn * math.pi * elapsed
	local actor = SheetActor(scene)
	if actor then
		actor:SetYaw((actor:GetYaw() or 0) + step)
		return
	end
	local camera = scene.GetActiveCamera and scene:GetActiveCamera()
	if camera and camera.GetYaw and camera.SetYaw then
		camera:SetYaw((camera:GetYaw() or 0) - step)
	else
		self:Hide()
	end
end)

local function RotateStart(direction)
	spinner.turn = direction == "left" and -1 or 1
	spinner:Show()
end

local function RotateStop()
	spinner:Hide()
end

local function RotateButton(parent, pathKey, direction, anchor, relPoint)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(U(35), U(35))
	button:SetPoint("TOPLEFT", anchor, relPoint, 0, 0)
	button:SetNormalTexture(BUTTONS .. pathKey .. "-Button-Up")
	button:SetPushedTexture(BUTTONS .. pathKey .. "-Button-Down")
	button:SetHighlightTexture(BUTTONS .. "ButtonHilight-Round")
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
	end
	if CharacterModelScene then
		button:SetFrameLevel(CharacterModelScene:GetFrameLevel() + 10)
	end
	button:SetScript("OnMouseDown", function()
		RotateStart(direction)
		if SOUNDKIT and SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER then
			pcall(PlaySound, SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER)
		end
	end)
	button:SetScript("OnMouseUp", RotateStop)
	button:SetScript("OnHide", RotateStop)
	return button
end

local function FitModelCamera()
	local scene = CharacterModelScene
	local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
	if not camera or camera.omqFitted then
		return
	end
	camera.omqFitted = true
	if type(scene.OnMouseWheel) == "function" then
		for _ = 1, 3 do
			pcall(scene.OnMouseWheel, scene, -1)
		end
	end
end

local function Ring(parent, path, lift)
	local holder = CharacterFrame.PortraitContainer
	local over = CreateFrame("Frame", nil, parent)
	over:SetSize(U(80), U(73))
	over:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
	over:SetFrameLevel((holder and holder:GetFrameLevel() or CharacterFrame:GetFrameLevel()) + lift)
	local tex = over:CreateTexture(nil, "ARTWORK")
	Art(tex, path)
	tex:SetAllPoints(over)
	tex:SetTexCoord(0, 80 / 256, 0, 73 / 256)
	return over
end

local function UpdateStats()
	if not built or not active or not PaperDollFrame or not PaperDollFrame:IsShown() then
		return
	end
	if sheet.level then
		sheet.level:SetText(LevelLine())
	end
	if type(UnitStat) ~= "function" then
		return
	end
	local _, probe = UnitStat("player", 1)
	if issecretvalue and issecretvalue(probe) then
		return
	end
	for i, row in ipairs(sheet.attributes) do
		local _, effective, pos, neg = UnitStat("player", i)
		local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
		row.value:SetText(text)
		row.tip = (_G["SPELL_STAT" .. i .. "_NAME"] or row.name) .. " " .. Number(effective)
		row.tip2 = detail
	end
	if type(UnitArmor) == "function" then
		local _, effective, _, pos, neg = UnitArmor("player")
		local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
		sheet.armor.value:SetText(text)
		sheet.armor.tip = (ARMOR or "Armor") .. " " .. Number(effective)
		sheet.armor.tip2 = detail
	end
	if type(UnitAttackBothHands) == "function" then
		local base, mod = UnitAttackBothHands("player")
		sheet.attack.value:SetText(Buffed(base, mod, 0))
	else
		sheet.attack.value:SetText("--")
	end
	if type(UnitAttackPower) == "function" then
		local base, pos, neg = UnitAttackPower("player")
		sheet.attackPower.value:SetText(Buffed(base, pos, neg))
	end
	if type(UnitDamage) == "function" then
		local minDamage, maxDamage = UnitDamage("player")
		minDamage, maxDamage = Number(minDamage), Number(maxDamage)
		sheet.damage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
	end
	local hasRanged = false
	if CharacterRangedSlot and CharacterRangedSlot:IsShown() and type(GetInventoryItemID) == "function" then
		local itemID = GetInventoryItemID("player", CharacterRangedSlot:GetID())
		hasRanged = itemID ~= nil and not (issecretvalue and issecretvalue(itemID))
	end
	if not hasRanged then
		sheet.rangedAttack.value:SetText("--")
		sheet.rangedPower.value:SetText("--")
		sheet.rangedDamage.value:SetText("--")
	else
		if type(UnitRangedAttack) == "function" then
			local base, mod = UnitRangedAttack("player")
			sheet.rangedAttack.value:SetText(Buffed(base, mod, 0))
		else
			sheet.rangedAttack.value:SetText("--")
		end
		if type(UnitRangedAttackPower) == "function" then
			local base, pos, neg = UnitRangedAttackPower("player")
			sheet.rangedPower.value:SetText(Buffed(base, pos, neg))
		end
		if type(UnitRangedDamage) == "function" then
			local _, minDamage, maxDamage = UnitRangedDamage("player")
			minDamage, maxDamage = Number(minDamage), Number(maxDamage)
			if maxDamage > 0 then
				sheet.rangedDamage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
			else
				sheet.rangedDamage.value:SetText("--")
			end
		end
	end
	if sheet.resistances and type(UnitResistance) == "function" then
		for _, res in ipairs(sheet.resistances) do
			local _, total = UnitResistance("player", res.id)
			res.value:SetText(Number(total))
		end
	end
end

local function TabPieces(tab, selected)
	local path = ART .. (selected and "UI-Character-ActiveTab" or "UI-Character-InActiveTab")
	local height = U(selected and 35 or 32)
	local bottom = selected and 0.546875 or 1
	local slices = {
		{ tab.left, tab.glowLeft, 0, 0.15625 },
		{ tab.middle, tab.glowMiddle, 0.15625, 0.84375 },
		{ tab.right, tab.glowRight, 0.84375, 1 },
	}
	for i = 1, #slices do
		local tex, glow, left, right = slices[i][1], slices[i][2], slices[i][3], slices[i][4]
		Art(tex, path)
		tex:SetTexCoord(left, right, 0, bottom)
		if glow then
			Art(glow, path)
			glow:SetTexCoord(left, right, 0, bottom)
		end
	end
	tab.left:SetSize(U(20), height)
	tab.right:SetSize(U(20), height)
end

local function ClassicTab(parent, index)
	local tab = CreateFrame("Button", "OldManQuesterCharacterTab" .. index, parent)
	tab:SetHeight(U(32))
	tab.left = tab:CreateTexture(nil, "BACKGROUND")
	tab.left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
	tab.right = tab:CreateTexture(nil, "BACKGROUND")
	tab.right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
	tab.middle = tab:CreateTexture(nil, "BACKGROUND")
	tab.middle:SetPoint("TOPLEFT", tab.left, "TOPRIGHT", 0, 0)
	tab.middle:SetPoint("BOTTOMRIGHT", tab.right, "BOTTOMLEFT", 0, 0)
	tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tab.text:SetPoint("CENTER", tab, "CENTER", 0, -3)
	tab.text:SetWordWrap(false)
	tab.text:SetJustifyH("CENTER")
	local parts = { left = "Left", middle = "Middle", right = "Right" }
	for key, name in pairs(parts) do
		local glow = tab:CreateTexture(nil, "HIGHLIGHT")
		glow:SetAllPoints(tab[key])
		glow:SetBlendMode("ADD")
		glow:SetAlpha(0.35)
		tab["glow" .. name] = glow
	end
	function tab:SetLabel(text)
		self.text:SetWidth(0)
		self.text:SetText(text)
		local width = math.min(U(106), math.ceil(self.text:GetStringWidth()) + U(30))
		self:SetWidth(width)
		self.text:SetWidth(width - U(20))
	end
	function tab:SetSelected(selected)
		TabPieces(self, selected)
		self.text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end
	TabPieces(tab, false)
	tab:EnableMouse(false)
	return tab
end

local function CoverTab(tab)
	local mode = tab and tab.mode
	if not mode or not mode.SetAllPoints then
		return
	end
	Remember(mode)
	local _, relativeTo = mode:GetPoint(1)
	if relativeTo ~= tab or mode:GetNumPoints() ~= 2 then
		mode:ClearAllPoints()
		mode:SetAllPoints(tab)
	end
	if mode:GetFrameLevel() <= tab:GetFrameLevel() then
		mode:SetFrameLevel(tab:GetFrameLevel() + 2)
	end
	if mode.SetHitRectInsets then
		mode:SetHitRectInsets(0, 0, 0, 0)
	end
	if not mode:IsMouseEnabled() then
		mode:EnableMouse(true)
	end
end

local function Build()
	if built or not CharacterFrame or not PaperDollFrame then
		return
	end
	built = true
	local frame, doll = CharacterFrame, PaperDollFrame
	sheet.general = {
		Piece(frame, ART .. "UI-Character-General-TopLeft", 256, 256, 0, 0, "BACKGROUND", -2),
		Piece(frame, ART .. "UI-Character-General-TopRight", 128, 256, 256, 0, "BACKGROUND", -2),
		Piece(frame, ART .. "UI-Character-General-BottomLeft", 256, 256, 0, -256, "BACKGROUND", -2),
		Piece(frame, ART .. "UI-Character-General-BottomRight", 128, 256, 256, -256, "BACKGROUND", -2),
	}
	sheet.doll = {
		Piece(doll, ART .. "UI-Character-CharacterTab-L1", 256, 256, 0, 0, "BACKGROUND", -1),
		Piece(doll, ART .. "UI-Character-CharacterTab-R1", 128, 256, 256, 0, "BACKGROUND", -1),
		Piece(doll, ART .. "UI-Character-CharacterTab-BottomLeft", 256, 256, 0, -256, "BACKGROUND", -1),
		Piece(doll, ART .. "UI-Character-CharacterTab-BottomRight", 128, 256, 256, -256, "BACKGROUND", -1),
	}
	sheet.ring = Ring(frame, ART .. "UI-Character-General-TopLeft", 1)
	sheet.dollRing = Ring(doll, ART .. "UI-Character-CharacterTab-L1", 2)

	local attrs = CreateFrame("Frame", nil, doll)
	attrs:SetSize(U(230), U(90))
	attrs:SetPoint("TOPLEFT", frame, "TOPLEFT", U(67), U(-291))
	StatBox(attrs, 0, 0, 53)
	StatBox(attrs, 115, 0, 12)
	StatBox(attrs, 115, -46, 11)
	if CharacterModelScene then
		attrs:SetFrameLevel(CharacterModelScene:GetFrameLevel() + 5)
	end
	sheet.attrs = attrs
	sheet.attributes = {}
	local prev
	local statNames = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
	for i = 1, 5 do
		local label = _G["SPELL_STAT" .. i .. "_NAME"] or statNames[i]
		local row = StatRow(attrs, label, prev or attrs, prev and "BOTTOMLEFT" or "TOPLEFT", prev and 0 or 6, prev and 0 or -3)
		row.name = statNames[i]
		sheet.attributes[i] = row
		prev = row
	end
	sheet.armor = StatRow(attrs, ARMOR or "Armor", prev, "BOTTOMLEFT", 0, 0)
	sheet.attack = StatRow(attrs, MELEE_ATTACK or "Melee Attack", attrs, "TOPLEFT", 122, -2, RIGHT_NUMBER_X, 122)
	sheet.attackPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.attack, "BOTTOMLEFT", 5, 1, RIGHT_NUMBER_X, 127)
	sheet.damage = StatRow(attrs, DAMAGE or "Damage", sheet.attackPower, "BOTTOMLEFT", 0, 1, RIGHT_NUMBER_X, 127)
	sheet.rangedAttack = StatRow(attrs, RANGED_ATTACK or "Ranged Attack", sheet.damage, "BOTTOMLEFT", -5, -6, RIGHT_NUMBER_X, 122)
	sheet.rangedPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.rangedAttack, "BOTTOMLEFT", 5, 1, RIGHT_NUMBER_X, 127)
	sheet.rangedDamage = StatRow(attrs, DAMAGE or "Damage", sheet.rangedPower, "BOTTOMLEFT", 0, 1, RIGHT_NUMBER_X, 127)

	if type(UnitResistance) == "function" then
		local resFrame = CreateFrame("Frame", nil, doll)
		resFrame:SetSize(U(32), U(160))
		resFrame:SetPoint("TOPRIGHT", frame, "TOPLEFT", U(297), U(-77))
		sheet.resFrame = resFrame
		sheet.resistances = {}
		prev = nil
		for i, res in ipairs(RESISTANCES) do
			local row = CreateFrame("Frame", nil, resFrame)
			row:SetSize(U(32), U(29))
			row:SetPoint("TOP", prev or resFrame, prev and "BOTTOM" or "TOP", 0, 0)
			local icon = row:CreateTexture(nil, "BACKGROUND")
			Art(icon, ART .. "UI-Character-ResistanceIcons")
			icon:SetAllPoints(row)
			icon:SetTexCoord(unpack(res.coords))
			row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.value:SetPoint("BOTTOM", row, "BOTTOM", 0, U(3))
			row.id = res.id
			row:EnableMouse(true)
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				local name = _G["DAMAGE_SCHOOL" .. (self.id + 1)] or _G["RESISTANCE" .. self.id .. "_NAME"] or ("Resistance " .. self.id)
				GameTooltip:SetText(name .. " " .. (RESISTANCE or "Resistance"), 1, 1, 1)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			sheet.resistances[i] = row
			prev = row
		end
	end

	if CharacterModelScene then
		sheet.rotateLeft = RotateButton(doll, "UI-RotationLeft", "left", CharacterModelScene, "TOPLEFT")
		sheet.rotateRight = RotateButton(doll, "UI-RotationRight", "right", sheet.rotateLeft, "TOPRIGHT")
	end

	sheet.level = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

	local watcher = CreateFrame("Frame")
	local events = {
		"UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED",
		"UNIT_RESISTANCES", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_LEVEL",
		"COMBAT_RATING_UPDATE", "UNIT_AURA",
	}
	for i = 1, #events do
		pcall(watcher.RegisterEvent, watcher, events[i])
	end
	watcher:SetScript("OnEvent", function(_, _, unit)
		if unit == nil or unit == "player" then
			UpdateStats()
		end
	end)
	doll:HookScript("OnShow", function()
		if active then
			UpdateStats()
		end
	end)
end

local function QuietMouse(frame, depth)
	if not frame then
		return
	end
	if frame.IsMouseEnabled and frame:IsMouseEnabled() then
		frame.omqMouseWas = true
		pcall(frame.EnableMouse, frame, false)
	end
	if depth < 8 and frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			QuietMouse(children[i], depth + 1)
		end
	end
end

local function LoudMouse(frame, depth)
	if not frame then
		return
	end
	if frame.omqMouseWas then
		frame.omqMouseWas = nil
		pcall(frame.EnableMouse, frame, true)
	end
	if depth < 8 and frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			LoudMouse(children[i], depth + 1)
		end
	end
end

local function Quiet(frame)
	if not frame or not frame.SetAlpha then
		return
	end
	if quieted[frame] == nil then
		quieted[frame] = frame:GetAlpha()
	end
	if frame:GetAlpha() > 0 then
		frame:SetAlpha(0)
	end
	QuietMouse(frame, 0)
end

local function Loud(frame)
	if not frame or quieted[frame] == nil then
		return
	end
	frame:SetAlpha(quieted[frame])
	quieted[frame] = nil
	LoudMouse(frame, 0)
end

local function HideSidePane(frame)
	Quiet(frame.RightPaneHost)
	Quiet(frame.RightPaneToggleButton)
	local skills = _G["SkillsFrame"]
	local keepDetail = skills and skills.SkillDetailFrame and skills:IsShown()
	if type(frame.SidePanes) == "table" then
		for _, pane in ipairs(frame.SidePanes) do
			if keepDetail and pane == skills.SkillDetailFrame then
				Loud(pane)
			else
				Quiet(pane)
			end
		end
	end
	for _, name in ipairs({ "CharacterStatsPane", "CharacterStatsPaneScrollBox", "PaperDollSidebarTabs", "PaperDollLevelInfo" }) do
		Quiet(_G[name])
	end
	if type(GetPaperDollSideBarFrame) == "function" and type(PAPERDOLL_SIDEBARS) == "table" then
		for i = 1, #PAPERDOLL_SIDEBARS do
			Quiet(GetPaperDollSideBarFrame(i))
		end
	end
	if frame.ModeTabs then
		frame.ModeTabs:SetAlpha(0)
		frame.ModeTabs:EnableMouse(false)
		if not frame.ModeTabs:IsShown() then
			frame.ModeTabs:Show()
		end
	end
	if frame.SetHitRectInsets and frame.GetWidth then
		local spare = math.max(0, math.floor((frame:GetWidth() or 0) - WIDTH))
		frame:SetHitRectInsets(0, spare, 0, 0)
	end
end

local function ScaleSlot(slot)
	if not slot.omqW then
		local w, h = slot:GetWidth(), slot:GetHeight()
		if not w or w <= 0 or not h or h <= 0 then
			return
		end
		slot.omqW, slot.omqH = w, h
	end
	slot:SetSize(U(slot.omqW), U(slot.omqH))
end

local function Column(names, x)
	local prev
	for i = 1, #names do
		local slot = _G[names[i]]
		if slot then
			Remember(slot)
			ScaleSlot(slot)
			slot:ClearAllPoints()
			if prev then
				slot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -U(SLOT_GAP))
			else
				slot:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(x), -U(74))
			end
			Fade(_G[names[i] .. "Frame"])
			Fade(slot.BorderFrame)
			prev = slot
		end
	end
end

local function PlaceTabs(frame)
	local strip = sheet.general and sheet.general[3]
	if not strip then
		return
	end
	local prev
	local function Place(tab)
		Remember(tab)
		tab:ClearAllPoints()
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", -U(15), 0)
		else
			tab:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", U(14), U(46))
		end
		prev = tab
	end
	if frame.ModeTabs and frame.ModeTabs.Tabs then
		sheet.tabs = sheet.tabs or {}
		for i, mode in ipairs(frame.ModeTabs.Tabs) do
			local tab = sheet.tabs[i]
			if not tab then
				tab = ClassicTab(frame, i)
				sheet.tabs[i] = tab
				if mode.HookScript then
					mode:HookScript("OnEnter", function(self)
						tab:LockHighlight()
						if GameTooltip and GameTooltip:GetOwner() == self then
							GameTooltip:Hide()
						end
					end)
					mode:HookScript("OnLeave", function()
						tab:UnlockHighlight()
					end)
				end
			end
			tab.mode = mode
			local label = TAB_LABELS[mode.frameName or ""] or mode.frameName or ""
			tab:SetLabel(label)
			tab:SetSelected(mode.frameName == frame.activeSubframe)
			tab:SetShown(mode:IsShown())
			if mode:IsShown() then
				Place(tab)
			end
			CoverTab(tab)
		end
		for i = 1, 6 do
			local retail = _G["CharacterFrameTab" .. i]
			if retail then
				Fade(retail)
				if retail.EnableMouse then
					retail:EnableMouse(false)
				end
			end
		end
	else
		for i = 1, 6 do
			local tab = _G["CharacterFrameTab" .. i]
			if tab and tab:IsShown() then
				Place(tab)
			end
		end
	end
end

local SKILL_SCALE = 20 / 33
local REP_SCALE = 0.76
local DETAIL_H = 124

local function FitScroll(frameName, scale, bottom)
	local frame = _G[frameName]
	local box = frame and frame.ScrollBox
	if not box or not active then
		return
	end
	local k = scale or 1
	bottom = bottom or 86
	Remember(box)
	if box.GetScale and box.omqScaleWas == nil then
		box.omqScaleWas = box:GetScale() or 1
	end
	box:ClearAllPoints()
	if box.SetScale then
		box:SetScale(k)
	end
	box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(12) / k, -U(76) / k)
	box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -U(66) / k, U(bottom) / k)
	if frame.ScrollBar then
		Remember(frame.ScrollBar)
		frame.ScrollBar:ClearAllPoints()
		frame.ScrollBar:SetPoint("TOPLEFT", box, "TOPRIGHT", U(6), -U(4))
		frame.ScrollBar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", U(6), U(4))
	end
	if frame.filterDropdown then
		Remember(frame.filterDropdown)
		frame.filterDropdown:ClearAllPoints()
		frame.filterDropdown:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -U(40), -U(62))
	end
end

local function FitLists()
	FitScroll("ReputationFrame", REP_SCALE, 86)
	local skillsShown = SkillsFrame and SkillsFrame:IsShown()
	FitScroll("SkillsFrame", SKILL_SCALE, skillsShown and (86 + DETAIL_H + 14) or 86)
	FitScroll("TokenFrame", 1, 86)
	FitScroll("StatisticsFrame", 1, 86)
	local detail = SkillsFrame and SkillsFrame.SkillDetailFrame
	if detail and skillsShown then
		Loud(detail)
		Remember(detail)
		detail:ClearAllPoints()
		detail:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", U(16), U(78))
		detail:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -U(36), U(78))
		detail:SetHeight(U(DETAIL_H))
		detail:Show()
	end
	local pvp = PVPRankFrame and PVPRankFrame.MainInfoFrame
	if pvp and active then
		Remember(pvp)
		pvp:ClearAllPoints()
		pvp:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(6), -U(70))
		pvp:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPRIGHT", -U(6), -U(205))
	end
	local rep = ReputationFrame
	if rep and active and rep:IsShown() then
		if not sheet.factionLabel then
			sheet.factionLabel = rep:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			sheet.standingLabel = rep:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		end
		sheet.factionLabel:ClearAllPoints()
		sheet.factionLabel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(86), -U(59))
		sheet.factionLabel:SetText(FACTION or "Faction")
		sheet.standingLabel:ClearAllPoints()
		sheet.standingLabel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(215), -U(59))
		sheet.standingLabel:SetText(STANDING or "Standing")
	end
end

local repDetail
local repFactionID

local function RepIndex(factionID)
	if not factionID or not C_Reputation or not C_Reputation.GetNumFactions then
		return nil
	end
	for index = 1, C_Reputation.GetNumFactions() do
		local data = C_Reputation.GetFactionDataByIndex(index)
		if data and data.factionID == factionID then
			return index, data
		end
	end
end

local function RepCheck(parent, label)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	local text = check.Text or check.text
	if not text then
		text = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		text:SetPoint("LEFT", check, "RIGHT", 0, 1)
		check.text = text
	end
	text:SetText(label)
	check.label = text
	return check
end

local function RefreshRepDetail()
	if not repDetail or not repDetail:IsShown() then
		return
	end
	local index, data = RepIndex(repFactionID)
	if not index or not data then
		repDetail:Hide()
		return
	end
	repDetail.index = index
	repDetail.name:SetText(data.name or "")
	repDetail.text:SetText(data.description or "")
	local canWar = data.canToggleAtWar and not data.isHeader
	repDetail.war:SetEnabled(canWar and true or false)
	repDetail.war:SetChecked(data.atWarWith and true or false)
	repDetail.inactive:SetEnabled(data.canSetInactive and true or false)
	local activeFaction = C_Reputation.IsFactionActive and C_Reputation.IsFactionActive(index)
	repDetail.inactive:SetChecked(activeFaction == false)
	repDetail.watch:SetChecked(data.isWatched and true or false)
end

local function BuildRepDetail()
	if repDetail or not CharacterFrame then
		return repDetail
	end
	local box = CreateFrame("Frame", "OldManQuesterReputationDetail", CharacterFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	box:SetSize(212, 203)
	box:SetFrameLevel(CharacterFrame:GetFrameLevel() + 30)
	box:EnableMouse(true)
	box:Hide()
	if box.SetBackdrop then
		box:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	box.name = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	box.name:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -21)
	box.name:SetWidth(150)
	box.name:SetJustifyH("LEFT")
	box.text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	box.text:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -4)
	box.text:SetSize(172, 90)
	box.text:SetJustifyH("LEFT")
	box.text:SetJustifyV("TOP")
	local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		box:Hide()
	end)
	box.war = RepCheck(box, AT_WAR or "At War")
	box.war:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -143)
	box.war:SetScript("OnClick", function(self)
		if box.index and C_Reputation.ToggleFactionAtWar then
			C_Reputation.ToggleFactionAtWar(box.index)
		end
		C_Timer.After(0.2, RefreshRepDetail)
	end)
	box.inactive = RepCheck(box, MOVE_TO_INACTIVE or "Move to Inactive")
	box.inactive:SetPoint("LEFT", box.war, "RIGHT", 70, 0)
	box.inactive:SetScript("OnClick", function(self)
		if box.index and C_Reputation.SetFactionActive then
			C_Reputation.SetFactionActive(box.index, not self:GetChecked())
		end
		C_Timer.After(0.2, RefreshRepDetail)
	end)
	box.watch = RepCheck(box, SHOW_FACTION_ON_MAINSCREEN or "Show as Experience Bar")
	box.watch:SetPoint("TOPLEFT", box.war, "BOTTOMLEFT", 0, 2)
	box.watch:SetScript("OnClick", function(self)
		if C_Reputation.SetWatchedFactionByIndex then
			C_Reputation.SetWatchedFactionByIndex(self:GetChecked() and box.index or 0)
		end
		C_Timer.After(0.2, RefreshRepDetail)
	end)
	box:SetScript("OnUpdate", function(self, elapsed)
		self.since = (self.since or 0) + elapsed
		if self.since < 0.2 then
			return
		end
		self.since = 0
		if not (ReputationFrame and ReputationFrame:IsVisible()) then
			self:Hide()
		end
	end)
	repDetail = box
	return box
end

local function ReputationClicked(row)
	if not active or not row then
		return
	end
	local data = row.elementData or (row.GetElementData and row:GetElementData())
	local factionID = data and data.factionID
	if not factionID or factionID <= 0 then
		return
	end
	local box = BuildRepDetail()
	if not box then
		return
	end
	if box:IsShown() and repFactionID == factionID then
		box:Hide()
		return
	end
	repFactionID = factionID
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", U(349), U(-48))
	box:Show()
	RefreshRepDetail()
end

local function WatchReputationRows()
	local box = ReputationFrame and ReputationFrame.ScrollBox
	if not box or not box.ForEachFrame then
		return
	end
	box:ForEachFrame(function(row)
		if row.omqRepClick or not row.HookScript then
			return
		end
		row.omqRepClick = true
		row:HookScript("OnClick", function(self)
			ReputationClicked(self)
		end)
	end)
end

local function SetPanelExtent(frame, width, height)
	if InCombatLockdown() or not frame.SetAttribute then
		return
	end
	pcall(frame.SetAttribute, frame, "UIPanelLayout-width", width)
	pcall(frame.SetAttribute, frame, "UIPanelLayout-height", height)
end

local function CollapseSetting()
	if InCombatLockdown() or not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then
		return
	end
	local ok, current = pcall(C_CVar.GetCVar, "characterFrameCollapsed")
	if not ok or current == nil then
		return
	end
	if savedCVar == nil then
		savedCVar = tostring(current)
	end
	if tostring(current) ~= "1" then
		pcall(C_CVar.SetCVar, "characterFrameCollapsed", "1")
	end
end

local function LayoutNow()
	if not active or not built or not CharacterFrame or not PaperDollFrame then
		return
	end
	local frame, doll = CharacterFrame, PaperDollFrame
	local scale = ns.FRAME_SCALE or 1
	RememberFrame(frame)
	frame:SetScale(scale)
	frame:SetSize(WIDTH, HEIGHT)
	SetPanelExtent(frame, WIDTH * scale, HEIGHT * scale)

	Fade(frame.NineSlice)
	Fade(frame.Bg)
	Fade(frame.TopTileStreaks)
	Fade(frame.Inset)
	Fade(frame.InsetRight)
	for i = 1, #MODEL_BACKGROUNDS do
		local key = MODEL_BACKGROUNDS[i]
		Fade(doll[key])
		if CharacterModelScene then
			Fade(CharacterModelScene[key])
		end
	end
	for i = 1, #INNER_BORDERS do
		Fade(_G[INNER_BORDERS[i]])
	end

	local controls = CharacterModelScene and CharacterModelScene.ControlFrame
	if controls then
		Fade(controls)
		controls:Hide()
		controls:EnableMouse(false)
		if not controls.omqHooked then
			controls.omqHooked = true
			controls:HookScript("OnShow", function(self)
				if active then
					self:Hide()
				end
			end)
		end
	end

	local pane = frame.LeftPaneHost
	if pane then
		Remember(pane)
		pane:ClearAllPoints()
		pane:SetPoint("TOPLEFT", frame, "TOPLEFT", U(6), -U(60))
		pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -U(6), U(82))
		local regions = { pane:GetRegions() }
		for i = 1, #regions do
			if regions[i].IsObjectType and regions[i]:IsObjectType("Texture") then
				Fade(regions[i])
			end
		end
	end
	if doll.SetClipsChildren then
		doll:SetClipsChildren(false)
	end

	HideSidePane(frame)

	local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
	if portrait then
		Remember(portrait)
		portrait:SetSize(U(62), U(62))
		portrait:ClearAllPoints()
		portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", U(9), -U(6))
		if SetPortraitTexture then
			SetPortraitTexture(portrait, "player")
		end
	end
	local holder = frame.PortraitContainer
	if holder and holder.GetRegions then
		local regions = { holder:GetRegions() }
		for i = 1, #regions do
			if regions[i].IsObjectType and regions[i]:IsObjectType("Texture") and regions[i] ~= portrait then
				Fade(regions[i])
			end
		end
	end

	local title = frame.TitleContainer and frame.TitleContainer.TitleText
	if frame.TitleContainer and frame.TitleContainer.GetRegions then
		local regions = { frame.TitleContainer:GetRegions() }
		for i = 1, #regions do
			if regions[i].IsObjectType and regions[i]:IsObjectType("Texture") then
				Fade(regions[i])
			end
		end
	end
	if title then
		Remember(title)
		title:ClearAllPoints()
		title:SetPoint("CENTER", frame, "TOP", U(6), -U(24))
		title:SetFontObject("GameFontNormal")
		local name = UnitName("player")
		if name and not (issecretvalue and issecretvalue(name)) and (not frame.activeSubframe or frame.activeSubframe == "PaperDollFrame") then
			title:SetText(name)
		end
	end
	if sheet.level and title then
		sheet.level:ClearAllPoints()
		sheet.level:SetPoint("TOP", title, "BOTTOM", 0, -U(6))
		sheet.level:SetText(LevelLine())
		sheet.level:Show()
	end
	Fade(CharacterLevelText)

	local close = frame.CloseButton
	if close then
		Remember(close)
		close:ClearAllPoints()
		close:SetPoint("CENTER", frame, "TOPRIGHT", -U(44), -U(25))
	end

	Column(LEFT_SLOTS, 21)
	Column(RIGHT_SLOTS, 306)
	local prev
	for i = 1, #WEAPON_SLOTS do
		local slot = _G[WEAPON_SLOTS[i]]
		if slot then
			Remember(slot)
			ScaleSlot(slot)
			slot:ClearAllPoints()
			if prev then
				slot:SetPoint("TOPLEFT", prev, "TOPRIGHT", U(5), 0)
			else
				slot:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", U(122), U(127))
			end
			Fade(_G[WEAPON_SLOTS[i] .. "Frame"])
			Fade(slot.BorderFrame)
			prev = slot
		end
	end
	local ammo = _G["CharacterAmmoSlot"]
	if ammo and prev then
		Remember(ammo)
		ScaleSlot(ammo)
		ammo:ClearAllPoints()
		ammo:SetPoint("LEFT", prev, "RIGHT", U(8), 0)
		Fade(_G["CharacterAmmoSlotFrame"])
		Fade(ammo.BorderFrame)
	end

	if CharacterModelScene then
		Remember(CharacterModelScene)
		CharacterModelScene:ClearAllPoints()
		CharacterModelScene:SetPoint("TOPLEFT", frame, "TOPLEFT", U(65), -U(78))
		CharacterModelScene:SetSize(U(233), U(224))
		FitModelCamera()
		local level = CharacterModelScene:GetFrameLevel() + 10
		if sheet.rotateLeft then
			sheet.rotateLeft:SetFrameLevel(level)
		end
		if sheet.rotateRight then
			sheet.rotateRight:SetFrameLevel(level)
		end
	end

	for i = 1, #sheet.general do
		sheet.general[i]:Show()
	end
	for i = 1, #sheet.doll do
		sheet.doll[i]:Show()
	end
	if sheet.ring then
		sheet.ring:Show()
	end
	if sheet.dollRing then
		sheet.dollRing:Show()
	end
	if sheet.attrs then
		sheet.attrs:Show()
	end
	if sheet.resFrame then
		sheet.resFrame:Show()
	end
	if sheet.rotateLeft then
		sheet.rotateLeft:Show()
	end
	if sheet.rotateRight then
		sheet.rotateRight:Show()
	end

	PlaceTabs(frame)
	FitLists()
	WatchReputationRows()
	UpdateStats()
	if frame:IsShown() and UpdateUIPanelPositions then
		pcall(UpdateUIPanelPositions, frame)
	end
end

local function Layout()
	if laying or not active then
		return
	end
	laying = true
	local ok, err = pcall(LayoutNow)
	laying = false
	if not ok and not reported then
		reported = true
		print("|cffffcc66OldManQuester|r: character window layout failed: " .. tostring(err))
	end
end

local function RestorePoints()
	for region, saved in pairs(placed) do
		if region.ClearAllPoints then
			region:ClearAllPoints()
			for i = 1, #saved.points do
				pcall(region.SetPoint, region, unpack(saved.points[i]))
			end
			if saved.width and saved.height and region.SetSize then
				pcall(region.SetSize, region, saved.width, saved.height)
			end
		end
	end
end

local function RestoreAlphas()
	for region, alpha in pairs(faded) do
		if region.SetAlpha then
			region:SetAlpha(alpha)
		end
	end
	for frame, alpha in pairs(quieted) do
		if frame.SetAlpha then
			frame:SetAlpha(alpha)
			LoudMouse(frame, 0)
		end
	end
end

local function HideOurs()
	if sheet.level then
		sheet.level:Hide()
	end
	for _, tab in ipairs(sheet.tabs or {}) do
		tab:Hide()
	end
	for _, tex in ipairs(sheet.general or {}) do
		tex:Hide()
	end
	for _, tex in ipairs(sheet.doll or {}) do
		tex:Hide()
	end
	if sheet.ring then
		sheet.ring:Hide()
	end
	if sheet.dollRing then
		sheet.dollRing:Hide()
	end
	if sheet.attrs then
		sheet.attrs:Hide()
	end
	if sheet.resFrame then
		sheet.resFrame:Hide()
	end
	if sheet.rotateLeft then
		sheet.rotateLeft:Hide()
	end
	if sheet.rotateRight then
		sheet.rotateRight:Hide()
	end
	if repDetail then
		repDetail:Hide()
	end
	RotateStop()
end

local function Restore()
	active = false
	if not built or not CharacterFrame then
		return
	end
	HideOurs()
	RestorePoints()
	RestoreAlphas()
	if CharacterFrame.SetHitRectInsets then
		CharacterFrame:SetHitRectInsets(0, 0, 0, 0)
	end
	local controls = CharacterModelScene and CharacterModelScene.ControlFrame
	if controls then
		controls:Show()
		controls:EnableMouse(true)
	end
	if origWidth then
		CharacterFrame:SetScale(origScale or 1)
		CharacterFrame:SetSize(origWidth, origHeight)
		SetPanelExtent(CharacterFrame, origWidth, origHeight)
	end
	for _, name in ipairs({ "ReputationFrame", "SkillsFrame", "TokenFrame", "StatisticsFrame" }) do
		local list = _G[name]
		local box = list and list.ScrollBox
		if box and box.omqScaleWas and box.SetScale then
			box:SetScale(box.omqScaleWas)
		end
	end
	if savedCVar and not InCombatLockdown() and C_CVar and C_CVar.SetCVar then
		pcall(C_CVar.SetCVar, "characterFrameCollapsed", savedCVar)
		savedCVar = nil
	end
	if CharacterFrame.UpdateSize then
		pcall(CharacterFrame.UpdateSize, CharacterFrame)
	end
end

local function WatchWhileShown(elapsed, watch)
	if not active or not CharacterFrame or not CharacterFrame:IsShown() then
		return
	end
	watch.since = (watch.since or 0) + elapsed
	if watch.since > 0.25 then
		watch.since = 0
		HideSidePane(CharacterFrame)
		WatchReputationRows()
		local tabs = PaperDollSidebarTabs
		local host = CharacterFrame.RightPaneHost
		if (tabs and tabs:IsShown() and tabs:GetAlpha() > 0) or (host and host:IsShown() and host:GetAlpha() > 0) then
			HideSidePane(CharacterFrame)
		end
	end
	for _, tab in ipairs(sheet.tabs or {}) do
		CoverTab(tab)
	end
end

local function InstallHooks()
	if hooked or not CharacterFrame or not PaperDollFrame then
		return
	end
	hooked = true
	if CharacterFrame.UpdateSize then
		hooksecurefunc(CharacterFrame, "UpdateSize", function()
			if active then
				Layout()
			end
		end)
	end
	if CharacterFrame.UpdateTabBounds then
		hooksecurefunc(CharacterFrame, "UpdateTabBounds", function()
			if active then
				Layout()
			end
		end)
	end
	if CharacterFrame.Expand then
		hooksecurefunc(CharacterFrame, "Expand", function(self)
			if active then
				HideSidePane(self)
			end
		end)
	end
	if CharacterFrame.RefreshRightPane then
		hooksecurefunc(CharacterFrame, "RefreshRightPane", function(self)
			if active then
				HideSidePane(self)
			end
		end)
	end
	if CharacterFrame.ShowSubFrame then
		hooksecurefunc(CharacterFrame, "ShowSubFrame", function()
			if active then
				C_Timer.After(0, Layout)
			end
		end)
	end
	if CharacterFrame.UpdatePortrait then
		hooksecurefunc(CharacterFrame, "UpdatePortrait", function(self)
			if not active then
				return
			end
			local portrait = self.PortraitContainer and self.PortraitContainer.portrait
			if portrait and SetPortraitTexture then
				SetPortraitTexture(portrait, "player")
			end
		end)
	end
	if type(PaperDollFrame_UpdateSidebarTabs) == "function" then
		hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
			if active and CharacterFrame then
				HideSidePane(CharacterFrame)
			end
		end)
	end
	PaperDollFrame:HookScript("OnSizeChanged", function()
		if active then
			Layout()
		end
	end)
	CharacterFrame:HookScript("OnShow", function()
		if not (ns.IsEnabled and ns.IsEnabled()) then
			return
		end
		RememberFrame(CharacterFrame)
		Build()
		active = true
		Layout()
	end)
	local watch = CreateFrame("Frame", nil, CharacterFrame)
	watch:SetScript("OnUpdate", function(self, elapsed)
		WatchWhileShown(elapsed, self)
	end)
	if CharacterModelScene and CharacterModelScene.TransitionToModelSceneID then
		hooksecurefunc(CharacterModelScene, "TransitionToModelSceneID", function()
			if active then
				C_Timer.After(0, FitModelCamera)
			end
		end)
	end
	local combat = CreateFrame("Frame")
	combat:RegisterEvent("PLAYER_REGEN_ENABLED")
	combat:SetScript("OnEvent", function()
		if active and CharacterFrame and CharacterFrame:IsShown() then
			Layout()
		end
	end)
	for _, name in ipairs({ "ReputationFrame", "SkillsFrame", "TokenFrame", "StatisticsFrame", "PVPRankFrame" }) do
		local frame = _G[name]
		if frame and frame.HookScript then
			frame:HookScript("OnShow", function()
				if active then
					C_Timer.After(0, Layout)
				end
			end)
		end
	end
end

function ns.ApplyCharacterWindow()
	if not CharacterFrame or not PaperDollFrame then
		return
	end
	InstallHooks()
	if not (ns.IsEnabled and ns.IsEnabled()) then
		Restore()
		return
	end
	RememberFrame(CharacterFrame)
	Build()
	active = true
	CollapseSetting()
	Layout()
end
