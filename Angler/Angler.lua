local PREFIX = "|cffffcc66Angler|r"

local MIN_DOUBLE_CLICK = 0.05
local MAX_DOUBLE_CLICK = 0.4
local IGNORE_LURE_SECONDS = 300
local LURE_BTN_SIZE = 28
local LURE_PADDING = 5
local BG_SOUND_CVAR = "Sound_EnableSoundWhenGameIsInBG"

local FISHING_SPELLS = { 7620, 131474 }
local LURES = { 6533, 6532, 7307, 6530, 6811, 6529 }

local lastClickTime = 0
local ignoreLureUntil = 0
local isFishing = false
local savedBGSound

local lureButtons = {}

local function Print(message)
	print(PREFIX .. ": " .. message)
end

local function BoolText(value)
	if value then
		return "ON"
	end
	return "OFF"
end

local function IsEnabled()
	return AnglerDB and AnglerDB.enabled
end

local function StatusText()
	return BoolText(IsEnabled())
		.. "  click " .. BoolText(AnglerDB.click)
		.. "  lures " .. BoolText(AnglerDB.lures)
		.. "  sound " .. BoolText(AnglerDB.sound)
end

local function PrintMenu()
	Print("/an on | off | status")
	print("/an click on | off")
	print("/an lures on | off")
	print("/an sound on | off")
	Print("Currently: " .. StatusText())
end

local function InitDB()
	if type(AnglerDB) ~= "table" then
		AnglerDB = {}
	end
	if AnglerDB.enabled == nil then
		AnglerDB.enabled = true
	end
	if AnglerDB.click == nil then
		AnglerDB.click = true
	end
	if AnglerDB.lures == nil then
		AnglerDB.lures = true
	end
	if AnglerDB.sound == nil then
		AnglerDB.sound = true
	end
end

local function GetFishingSpellName()
	for i = 1, #FISHING_SPELLS do
		local name = C_Spell.GetSpellName(FISHING_SPELLS[i])
		if name then
			return name
		end
	end
	return "Fishing"
end

local function IsFishingSpell(spellID)
	local id = tonumber(spellID)
	if not id then
		return false
	end
	for i = 1, #FISHING_SPELLS do
		if id == FISHING_SPELLS[i] then
			return true
		end
	end
	return false
end

local function IsFishingPoleEquipped()
	local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
	if not itemID then
		return false
	end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	if classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole then
		return true
	end
	return false
end

local function HasPoleLure()
	return C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND) ~= nil
end

local function GetAvailableLures()
	local available = {}
	for i = 1, #LURES do
		local lureID = LURES[i]
		local count = C_Item.GetItemCount(lureID)
		if count and count > 0 then
			available[#available + 1] = { id = lureID, count = count }
		end
	end
	return available
end

local castButton = CreateFrame("Button", "AnglerCastButton", UIParent, "SecureActionButtonTemplate")
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:EnableMouse(false)

local function ClearCastBinding()
	if not InCombatLockdown() then
		ClearOverrideBindings(castButton)
	end
end

local lureMenu = CreateFrame("Frame", "AnglerLureMenu", UIParent, "BackdropTemplate")
lureMenu:SetFrameStrata("DIALOG")
lureMenu:SetToplevel(true)
lureMenu:Hide()
lureMenu:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
lureMenu:SetBackdropColor(0.08, 0.08, 0.09, 0.96)
lureMenu:SetBackdropBorderColor(0.15, 0.15, 0.16, 1)
tinsert(UISpecialFrames, "AnglerLureMenu")

local function HideLureMenu()
	if lureMenu:IsShown() and not InCombatLockdown() then
		lureMenu:Hide()
	end
end

local lureMenuCloseBtn = CreateFrame("Button", nil, lureMenu)
lureMenuCloseBtn:SetSize(20, 20)
lureMenuCloseBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
lureMenuCloseBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
lureMenuCloseBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
lureMenuCloseBtn:SetScript("OnClick", function()
	ignoreLureUntil = GetTime() + IGNORE_LURE_SECONDS
	HideLureMenu()
end)
lureMenuCloseBtn:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -5)
	GameTooltip:SetText("Ignore Lures")
	GameTooltip:AddLine("Fish without lures for the next 5 minutes.", 1, 1, 1, true)
	GameTooltip:Show()
end)
lureMenuCloseBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

local function MakeLureButton(index)
	local btn = CreateFrame("Button", "AnglerLureBtn" .. index, lureMenu, "SecureActionButtonTemplate")
	btn:SetSize(LURE_BTN_SIZE, LURE_BTN_SIZE)
	btn:RegisterForClicks("AnyUp", "AnyDown")

	local tex = btn:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.icon = tex

	local mask = btn:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(btn.icon)
	btn.icon:AddMaskTexture(mask)

	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	btn:GetHighlightTexture():SetBlendMode("ADD")
	btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

	local font = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	font:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
	btn.Count = font

	btn:SetScript("OnEnter", function(self)
		if not self.itemID then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -5)
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	btn:SetScript("PostClick", function()
		HideLureMenu()
	end)

	return btn
end

local function UpdateLureMenu(availableLures)
	for i = 1, #lureButtons do
		lureButtons[i]:Hide()
	end

	if #availableLures == 0 then
		return false
	end

	local width = (#availableLures * LURE_BTN_SIZE) + ((#availableLures + 1) * LURE_PADDING)
	lureMenu:SetSize(width, LURE_BTN_SIZE + 2 * LURE_PADDING)

	lureMenuCloseBtn:ClearAllPoints()
	lureMenuCloseBtn:SetPoint("CENTER", lureMenu, "TOPRIGHT", 0, 0)

	for i = 1, #availableLures do
		local lure = availableLures[i]
		local btn = lureButtons[i]
		if not btn then
			btn = MakeLureButton(i)
			lureButtons[i] = btn
		end

		btn.itemID = lure.id
		btn:ClearAllPoints()
		btn:SetPoint("LEFT", lureMenu, "LEFT", LURE_PADDING + (i - 1) * (LURE_BTN_SIZE + LURE_PADDING), 0)
		btn.icon:SetTexture(C_Item.GetItemIconByID(lure.id))
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("macrotext", "/use item:" .. lure.id .. "\n/use " .. INVSLOT_MAINHAND)
		if lure.count > 1 then
			btn.Count:SetText(lure.count)
		else
			btn.Count:SetText("")
		end
		btn:Show()
	end
	return true
end

local function ShowLureMenu()
	if InCombatLockdown() then
		return
	end
	if not IsEnabled() or not AnglerDB.lures then
		return
	end
	if HasPoleLure() then
		ignoreLureUntil = 0
		return
	end
	if GetTime() <= ignoreLureUntil then
		return
	end
	local lures = GetAvailableLures()
	if not UpdateLureMenu(lures) then
		return
	end
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	lureMenu:ClearAllPoints()
	lureMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 40, (y / scale) - 20)
	lureMenu:Show()
end

local function EnableBGSound()
	if not IsEnabled() or not AnglerDB.sound then
		return
	end
	local current = C_CVar.GetCVar(BG_SOUND_CVAR)
	if savedBGSound == nil then
		savedBGSound = current
	end
	if current ~= "1" then
		C_CVar.SetCVar(BG_SOUND_CVAR, "1")
	end
end

local function RestoreBGSound()
	if savedBGSound == nil then
		return
	end
	C_CVar.SetCVar(BG_SOUND_CVAR, savedBGSound)
	savedBGSound = nil
end

local function StopFishing()
	if not isFishing then
		return
	end
	isFishing = false
	RestoreBGSound()
end

local function OnGlobalMouseDown(buttonName)
	if buttonName ~= "RightButton" then
		lastClickTime = 0
		ClearCastBinding()
		return
	end
	if not IsEnabled() or not AnglerDB.click then
		lastClickTime = 0
		ClearCastBinding()
		return
	end
	if InCombatLockdown() then
		lastClickTime = 0
		return
	end
	if not IsFishingPoleEquipped() or UnitExists("mouseover") then
		lastClickTime = 0
		ClearCastBinding()
		return
	end
	local speed = tonumber(GetUnitSpeed("player"))
	if speed and speed > 0 then
		lastClickTime = 0
		ClearCastBinding()
		return
	end
	local now = GetTime()
	if lastClickTime > 0 and (now - lastClickTime < MAX_DOUBLE_CLICK) and (now - lastClickTime > MIN_DOUBLE_CLICK) then
		lastClickTime = 0
		local spellName = GetFishingSpellName()
		if spellName then
			SetOverrideBindingSpell(castButton, true, "BUTTON2", spellName)
		end
	else
		lastClickTime = now
		ClearCastBinding()
	end
end

local function SetEnabled(enabled)
	AnglerDB.enabled = enabled
	if not enabled then
		ClearCastBinding()
		HideLureMenu()
		StopFishing()
	end
	Print(StatusText())
end

local function SetFlag(key, value)
	AnglerDB[key] = value
	if key == "click" and not value then
		ClearCastBinding()
	elseif key == "lures" and not value then
		HideLureMenu()
	elseif key == "sound" and not value then
		RestoreBGSound()
	end
	Print(StatusText())
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	local cmd, rest = string.match(msg, "^(%S+)%s*(.-)%s*$")
	cmd = cmd or ""
	rest = rest or ""
	if cmd == "on" then
		SetEnabled(true)
	elseif cmd == "off" then
		SetEnabled(false)
	elseif cmd == "status" then
		Print(StatusText())
	elseif cmd == "click" or cmd == "lures" or cmd == "sound" then
		if rest == "on" then
			SetFlag(cmd, true)
		elseif rest == "off" then
			SetFlag(cmd, false)
		else
			PrintMenu()
		end
	else
		PrintMenu()
	end
end

local frame = CreateFrame("Frame")
local function OnEvent(_, event, ...)
	if event == "PLAYER_LOGIN" then
		InitDB()
		Print("loaded. Type /an for the menu.")
		return
	end
	if event == "PLAYER_LOGOUT" then
		RestoreBGSound()
		return
	end
	if type(AnglerDB) ~= "table" then
		return
	end
	if event == "GLOBAL_MOUSE_DOWN" then
		OnGlobalMouseDown(...)
	elseif event == "PLAYER_REGEN_DISABLED" then
		ClearCastBinding()
		HideLureMenu()
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		local unit, _, spellID = ...
		if unit ~= "player" or not IsEnabled() then
			return
		end
		if not IsFishingSpell(spellID) then
			return
		end
		isFishing = true
		EnableBGSound()
		ShowLureMenu()
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		local unit = ...
		if unit == "player" then
			StopFishing()
		end
	end
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

SLASH_ANGLER1 = "/an"
SLASH_ANGLER2 = "/angler"
SlashCmdList["ANGLER"] = HandleSlash
