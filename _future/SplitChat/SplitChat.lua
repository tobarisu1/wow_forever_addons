local addonName = ...

local PREFIX = "|cffffcc66SplitChat|r"
local LAYOUT_VERSION = 4
local DEFAULT_FONT = 20
local DEFAULT_FACE = "arial"
local FONT_SIZES = { [12] = true, [14] = true, [16] = true, [18] = true, [20] = true, [24] = true, [27] = true }
local FONT_FACES = {
	arial = "Fonts\\ARIALN.TTF",
	narrow = "Fonts\\ARIALN.TTF",
	default = "Fonts\\ARIALN.TTF",
	friz = "Fonts\\FRIZQT__.TTF",
	morpheus = "Fonts\\MORPHEUS.ttf",
	skurri = "Fonts\\skurri.ttf",
	["2002"] = "Fonts\\2002.TTF",
}
local FONT_FACE_ORDER = { "arial", "friz", "morpheus", "skurri", "2002" }
local DEFAULT_WIDTH = 500
local DEFAULT_HEIGHT = 300
local HEADER = 26
local PAD = 10
local EDIT_PAD = 36
local GRIP_WIDTH = 56
local MAX_WINDOWS = (Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows) or 10

local leftPanel, rightPanel
local commEntries = {}
local logEntries = {}
local commTabs = {}
local logTabs = {}
local selectedComm
local selectedLog
local hooked
local parking
local layoutReady
local mirrors = {}

local COMM_WINDOWS = {
	{ name = "Guild", groups = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "GUILD_DISCORD" } },
	{
		name = "Group",
		groups = {
			"PARTY",
			"PARTY_LEADER",
			"RAID",
			"RAID_LEADER",
			"RAID_WARNING",
			"INSTANCE_CHAT",
			"INSTANCE_CHAT_LEADER",
		},
	},
	{ name = "Whisper", groups = { "WHISPER", "BN_WHISPER" }, whispers = true },
}

local LOG_WINDOWS = {
	{ name = "Loot", groups = { "LOOT", "MONEY", "CURRENCY", "TRADESKILLS", "OPENING" } },
	{
		name = "World",
		groups = {
			"SKILL",
			"COMBAT_FACTION_CHANGE",
			"COMBAT_XP_GAIN",
			"COMBAT_HONOR_GAIN",
			"ACHIEVEMENT",
			"COMBAT_MISC_INFO",
			"PET_INFO",
			"PET_BATTLE_COMBAT_LOG",
			"PET_BATTLE_INFO",
		},
	},
	{
		name = "System",
		groups = {
			"SYSTEM",
			"ERRORS",
			"IGNORED",
			"CHANNEL",
			"TARGETICONS",
			"BG_HORDE",
			"BG_ALLIANCE",
			"BG_NEUTRAL",
		},
	},
}

local GENERAL_GROUPS = {
	"SAY",
	"EMOTE",
	"YELL",
	"MONSTER_SAY",
	"MONSTER_YELL",
	"MONSTER_EMOTE",
	"MONSTER_WHISPER",
	"MONSTER_BOSS_EMOTE",
	"MONSTER_BOSS_WHISPER",
	"COMMUNITIES_CHANNEL",
	"VOICE_TEXT",
	"PING",
	"AFK",
	"DND",
	"BN_INLINE_TOAST_ALERT",
}

local SKIP_CLASS_COLOR = {
	BN_WHISPER = true,
	BN_WHISPER_INFORM = true,
}

local CHAT_ART = {
	"Background",
	"TopLeftTexture",
	"BottomLeftTexture",
	"TopRightTexture",
	"BottomRightTexture",
	"LeftTexture",
	"RightTexture",
	"BottomTexture",
	"TopTexture",
}

local function Print(message)
	print(PREFIX .. ": " .. message)
end

local function BoolText(value)
	if value then
		return "ON"
	end
	return "OFF"
end

local function CopyDefaults(src, dest)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dest[key]) ~= "table" then
				dest[key] = {}
			end
			CopyDefaults(value, dest[key])
		elseif dest[key] == nil then
			dest[key] = value
		end
	end
end

local function InitDB()
	if type(SplitChatDB) ~= "table" then
		SplitChatDB = {}
	end
	CopyDefaults({
		enabled = true,
		locked = false,
		fontSize = DEFAULT_FONT,
		fontFace = DEFAULT_FACE,
		layoutVersion = 0,
		left = { point = "BOTTOMLEFT", x = 20, y = 90, w = DEFAULT_WIDTH, h = DEFAULT_HEIGHT },
		right = { point = "BOTTOMRIGHT", x = -20, y = 90, w = DEFAULT_WIDTH, h = DEFAULT_HEIGHT },
		rightTab = "Combat",
		leftTab = "General",
	}, SplitChatDB)
end

local function IsEnabled()
	return SplitChatDB and SplitChatDB.enabled
end

local function IsLocked()
	return SplitChatDB and SplitChatDB.locked
end

local function MaxWindowCount()
	return MAX_WINDOWS
end

local function CanonicalFace(name)
	if not name or name == "" then
		return DEFAULT_FACE
	end
	if FONT_FACES[name] then
		if name == "narrow" or name == "default" then
			return DEFAULT_FACE
		end
		return name
	end
	return nil
end

local function FontPath()
	return FONT_FACES[CanonicalFace(SplitChatDB and SplitChatDB.fontFace) or DEFAULT_FACE]
end

local function FontFlags(fontObject)
	if not fontObject or not fontObject.GetFont then
		return ""
	end
	local _, _, flags = fontObject:GetFont()
	return flags or ""
end

local function FindWindowByName(name)
	for i = 1, MaxWindowCount() do
		local windowName = FCF_GetChatWindowInfo(i)
		if windowName == name then
			return _G["ChatFrame" .. i]
		end
		local tab = _G["ChatFrame" .. i .. "Tab"]
		if tab and tab.GetText and tab:GetText() == name then
			return _G["ChatFrame" .. i]
		end
	end
end

local function AddGroups(frame, groups)
	if not frame or not groups or not frame.AddMessageGroup then
		return
	end
	for i = 1, #groups do
		frame:AddMessageGroup(groups[i])
	end
end

local function ClearGroups(frame)
	if frame and frame.RemoveAllMessageGroups then
		frame:RemoveAllMessageGroups()
	end
	if frame and frame.RemoveAllChannels then
		frame:RemoveAllChannels()
	end
end

local function AddJoinedChannels(frame)
	if not frame or not GetChannelList then
		return
	end
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local channelName = list[i + 1]
		if type(channelName) == "string" and channelName ~= "" then
			frame:AddChannel(channelName)
		end
	end
end

local function ConfigureWindow(frame, spec)
	if not frame then
		return
	end
	ClearGroups(frame)
	AddGroups(frame, spec.groups)
	if spec.whispers and frame.ReceiveAllPrivateMessages then
		frame:ReceiveAllPrivateMessages()
	end
	FCF_SetWindowName(frame, spec.name)
end

local function OpenNamedWindow(name)
	local existing = FindWindowByName(name)
	if existing then
		return existing
	end
	if FCF_OpenNewWindow then
		return FCF_OpenNewWindow(name, true)
	end
end

local function EnableClassColors()
	if C_CVar and C_CVar.SetCVar then
		C_CVar.SetCVar("chatClassColorOverride", "0")
	elseif SetCVar then
		SetCVar("chatClassColorOverride", "0")
	end
	if not SetChatColorNameByClass or type(ChatTypeInfo) ~= "table" then
		return
	end
	for chatType, info in pairs(ChatTypeInfo) do
		if type(chatType) == "string" and not SKIP_CLASS_COLOR[chatType] then
			SetChatColorNameByClass(chatType, true)
			if type(info) == "table" then
				info.colorNameByClass = true
			end
		end
	end
end

local function SetChatArtShown(frame, shown)
	if not frame then
		return
	end
	local name = frame:GetName()
	local textures = CHAT_FRAME_TEXTURES or CHAT_ART
	for _, suffix in pairs(textures) do
		local region = _G[name .. suffix]
		if region then
			if shown then
				region:Show()
			else
				region:SetAlpha(0)
				region:Hide()
			end
		end
	end
	if frame.Background then
		frame.Background:SetShown(shown)
	end
	if frame.buttonFrame then
		frame.buttonFrame:SetShown(shown)
	end
	if frame.ResizeButton then
		frame.ResizeButton:SetShown(shown)
	end
	if frame.ScrollBar then
		frame.ScrollBar:SetShown(shown)
	end
	if frame.ScrollToBottomButton then
		frame.ScrollToBottomButton:SetShown(shown)
	end
	if frame.EditModeResizeButton then
		frame.EditModeResizeButton:Hide()
	end
	local tab = _G[frame:GetName() .. "Tab"]
	if tab then
		if shown then
			tab:SetAlpha(1)
			tab:EnableMouse(true)
			tab:Show()
		else
			tab:SetAlpha(0)
			tab:EnableMouse(false)
			tab:Hide()
		end
	end
end

local function SetBlizzardDockShown(shown)
	if GeneralDockManager then
		GeneralDockManager:SetShown(shown)
	end
	if ChatFrameMenuButton then
		ChatFrameMenuButton:SetShown(shown)
	end
	if ChatFrameChannelButton then
		ChatFrameChannelButton:SetShown(shown)
	end
	if ChatFrameToggleVoiceDeafenButton then
		ChatFrameToggleVoiceDeafenButton:SetShown(shown)
	end
	if ChatFrameToggleVoiceMuteButton then
		ChatFrameToggleVoiceMuteButton:SetShown(shown)
	end
	if QuickJoinToastButton then
		QuickJoinToastButton:SetShown(shown)
	end
	if CombatLogQuickButtonFrame then
		CombatLogQuickButtonFrame:SetShown(shown)
	end
	if CombatLogQuickButtonFrame_Custom then
		CombatLogQuickButtonFrame_Custom:SetShown(shown)
	end
end

local function OpenChatConfig(chatFrame)
	if not chatFrame or not ChatConfigFrame then
		return
	end
	CURRENT_CHAT_FRAME_ID = chatFrame:GetID()
	SELECTED_CHAT_FRAME = chatFrame
	ShowUIPanel(ChatConfigFrame)
	if ChatConfigFrame.ChatTabManager then
		if ChatConfigFrame.ChatTabManager.UpdateTabDisplay then
			ChatConfigFrame.ChatTabManager:UpdateTabDisplay()
		end
		if ChatConfigFrame.ChatTabManager.UpdateSelection then
			ChatConfigFrame.ChatTabManager:UpdateSelection(chatFrame:GetID())
		end
	end
end

local function ApplyFontToSMF(smf)
	if not smf or not smf.SetFont then
		return
	end
	smf:SetFont(FontPath(), SplitChatDB.fontSize or DEFAULT_FONT, FontFlags(smf))
end

local function MakeDisplay(parent)
	local smf = CreateFrame("ScrollingMessageFrame", nil, parent)
	smf:SetPoint("TOPLEFT")
	smf:SetPoint("BOTTOMRIGHT")
	if smf.SetTimeVisible then
		smf:SetTimeVisible(300)
	end
	if smf.SetMaxLines then
		smf:SetMaxLines(256)
	end
	if smf.SetFading then
		smf:SetFading(false)
	end
	if smf.SetIndentedWordWrap then
		smf:SetIndentedWordWrap(true)
	end
	smf:SetJustifyH("LEFT")
	if smf.SetInsertMode then
		smf:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or 2)
	end
	smf:EnableMouse(true)
	smf:EnableMouseWheel(true)
	if smf.SetHyperlinksEnabled then
		smf:SetHyperlinksEnabled(true)
	end
	smf:SetScript("OnHyperlinkClick", function(self, link, text, button)
		if SetItemRef then
			SetItemRef(link, text, button, self)
		end
	end)
	smf:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			self:ScrollUp()
		else
			self:ScrollDown()
		end
	end)
	ApplyFontToSMF(smf)
	return smf
end

local function HookMirror(bliz, display)
	mirrors[bliz] = display
	if bliz.SplitChatMirrorHooked then
		return
	end
	bliz.SplitChatMirrorHooked = true
	hooksecurefunc(bliz, "AddMessage", function(self, message, r, g, b)
		local dest = mirrors[self]
		if dest and message ~= nil then
			dest:AddMessage(message, r, g, b)
		end
	end)
end

local function ParkBlizzardFrame(frame)
	if not frame then
		return
	end
	if frame.SetToplevel then
		frame:SetToplevel(false)
	end
	frame:SetClampedToScreen(false)
	if frame.SetClampRectInsets then
		frame:SetClampRectInsets(0, 0, 0, 0)
	end
	frame:SetAlpha(0)
	if frame.EnableMouse then
		frame:EnableMouse(false)
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2500, -2500)
	frame:SetSize(80, 80)
	SetChatArtShown(frame, false)
	frame:Show()
	SetChatWindowShown(frame:GetID(), true)
end

local function PlaceEditBox()
	local edit = ChatFrame1 and ChatFrame1.editBox
	if not edit or not leftPanel then
		return
	end
	edit:SetParent(leftPanel)
	edit:ClearAllPoints()
	edit:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMLEFT", 4, 4)
	edit:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -4, 4)
	edit:SetFrameStrata(leftPanel:GetFrameStrata())
	edit:SetFrameLevel((leftPanel:GetFrameLevel() or 1) + 6)
	if edit.SetFont then
		edit:SetFont(FontPath(), SplitChatDB.fontSize or DEFAULT_FONT, FontFlags(edit))
	end
end

local function RestoreEditBox()
	local edit = ChatFrame1 and ChatFrame1.editBox
	if not edit then
		return
	end
	edit:SetParent(ChatFrame1)
	edit:ClearAllPoints()
	edit:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", -5, -2)
	edit:SetPoint("RIGHT", ChatFrame1, "RIGHT", 8, 0)
end

local function SavePanel(panel, key)
	if not panel then
		return
	end
	local point, _, _, x, y = panel:GetPoint(1)
	SplitChatDB[key] = SplitChatDB[key] or {}
	SplitChatDB[key].point = point or SplitChatDB[key].point
	SplitChatDB[key].x = x or SplitChatDB[key].x
	SplitChatDB[key].y = y or SplitChatDB[key].y
	SplitChatDB[key].w = panel:GetWidth()
	SplitChatDB[key].h = panel:GetHeight()
end

local function PlacePanel(panel, key, fallbackPoint, fallbackX)
	local info = SplitChatDB[key] or {}
	panel:ClearAllPoints()
	panel:SetSize(info.w or DEFAULT_WIDTH, info.h or DEFAULT_HEIGHT)
	panel:SetPoint(info.point or fallbackPoint, UIParent, info.point or fallbackPoint, info.x or fallbackX, info.y or 90)
end

local function SetPanelsLocked(locked)
	local mouse = not locked
	if leftPanel then
		leftPanel.grip:EnableMouse(mouse)
		leftPanel.resize:SetShown(mouse)
	end
	if rightPanel then
		rightPanel.grip:EnableMouse(mouse)
		rightPanel.resize:SetShown(mouse)
	end
end

local function SelectedBlizzardFrame()
	for i = 1, #commEntries do
		if commEntries[i].name == selectedComm then
			return commEntries[i].source
		end
	end
	return ChatFrame1
end

local function SelectComm(name)
	selectedComm = name
	SplitChatDB.leftTab = name
	for i = 1, #commEntries do
		local entry = commEntries[i]
		local selected = entry.name == name
		entry.display:SetShown(selected)
		if commTabs[entry.name] then
			if selected then
				commTabs[entry.name]:SetNormalFontObject("GameFontHighlightSmall")
			else
				commTabs[entry.name]:SetNormalFontObject("GameFontNormalSmall")
			end
		end
	end
end

local function SelectLog(name)
	selectedLog = name
	SplitChatDB.rightTab = name
	for i = 1, #logEntries do
		local entry = logEntries[i]
		local selected = entry.name == name
		entry.display:SetShown(selected)
		if logTabs[entry.name] then
			if selected then
				logTabs[entry.name]:SetNormalFontObject("GameFontHighlightSmall")
			else
				logTabs[entry.name]:SetNormalFontObject("GameFontNormalSmall")
			end
		end
	end
end

local function StyleTab(tab, onLeft, onRight)
	tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	tab:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			onRight()
			return
		end
		onLeft()
	end)
end

local function BuildCommTabs()
	for _, tab in pairs(commTabs) do
		tab:Hide()
	end
	commTabs = {}
	local x = PAD
	for i = 1, #commEntries do
		local entry = commEntries[i]
		local tab = CreateFrame("Button", nil, leftPanel)
		tab:SetSize(56, 18)
		tab:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", x, -4)
		tab:SetNormalFontObject("GameFontNormalSmall")
		tab:SetHighlightFontObject("GameFontHighlightSmall")
		tab:SetText(entry.name)
		StyleTab(tab, function()
			SelectComm(entry.name)
		end, function()
			SelectComm(entry.name)
			OpenChatConfig(entry.source)
		end)
		commTabs[entry.name] = tab
		x = x + 58
	end
end

local function BuildLogTabs()
	for _, tab in pairs(logTabs) do
		tab:Hide()
	end
	logTabs = {}
	local x = PAD
	for i = 1, #logEntries do
		local entry = logEntries[i]
		local tab = CreateFrame("Button", nil, rightPanel)
		tab:SetSize(56, 18)
		tab:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", x, -4)
		tab:SetNormalFontObject("GameFontNormalSmall")
		tab:SetHighlightFontObject("GameFontHighlightSmall")
		tab:SetText(entry.name)
		StyleTab(tab, function()
			SelectLog(entry.name)
		end, function()
			SelectLog(entry.name)
			OpenChatConfig(entry.source)
		end)
		logTabs[entry.name] = tab
		x = x + 58
	end
end

local function BindEntry(name, source, panel, list)
	if not source or not panel or not panel.well then
		return
	end
	local display = MakeDisplay(panel.well)
	display:SetPoint("BOTTOMRIGHT", -0, 0)
	HookMirror(source, display)
	list[#list + 1] = { name = name, source = source, display = display }
end

local function BuildDisplays()
	for i = 1, #commEntries do
		if commEntries[i].display then
			commEntries[i].display:Hide()
		end
	end
	for i = 1, #logEntries do
		if logEntries[i].display then
			logEntries[i].display:Hide()
		end
	end
	commEntries = {}
	logEntries = {}

	BindEntry("General", ChatFrame1, leftPanel, commEntries)
	for i = 1, #COMM_WINDOWS do
		local spec = COMM_WINDOWS[i]
		BindEntry(spec.name, FindWindowByName(spec.name), leftPanel, commEntries)
	end

	BindEntry("Combat", ChatFrame2, rightPanel, logEntries)
	for i = 1, #LOG_WINDOWS do
		local spec = LOG_WINDOWS[i]
		BindEntry(spec.name, FindWindowByName(spec.name), rightPanel, logEntries)
	end
end

local function ApplyMessageGroups()
	ClearGroups(ChatFrame1)
	AddGroups(ChatFrame1, GENERAL_GROUPS)
	AddJoinedChannels(ChatFrame1)
	FCF_SetWindowName(ChatFrame1, GENERAL or "General")

	for i = 1, #COMM_WINDOWS do
		local spec = COMM_WINDOWS[i]
		local frame = FindWindowByName(spec.name)
		if frame then
			ConfigureWindow(frame, spec)
		end
	end

	local lootFrame
	for i = 1, #LOG_WINDOWS do
		local spec = LOG_WINDOWS[i]
		local frame = FindWindowByName(spec.name)
		if frame then
			ConfigureWindow(frame, spec)
			if spec.name == "Loot" then
				lootFrame = frame
			end
		end
	end
	if not lootFrame then
		AddGroups(ChatFrame1, LOG_WINDOWS[1].groups)
	end
end

local function EnsureWindows()
	if ChatFrame2 and FCF_SetWindowName then
		FCF_SetWindowName(ChatFrame2, COMBAT_LOG or "Combat")
	end
	for i = 1, #COMM_WINDOWS do
		OpenNamedWindow(COMM_WINDOWS[i].name)
	end
	for i = 1, #LOG_WINDOWS do
		OpenNamedWindow(LOG_WINDOWS[i].name)
	end
end

local function ApplyChatLayout(force)
	EnsureWindows()
	if force or (SplitChatDB.layoutVersion or 0) < LAYOUT_VERSION then
		ApplyMessageGroups()
		SplitChatDB.layoutVersion = LAYOUT_VERSION
	end
end

local function EachManagedFrame(fn)
	fn(ChatFrame1)
	fn(ChatFrame2)
	for i = 1, #COMM_WINDOWS do
		fn(FindWindowByName(COMM_WINDOWS[i].name))
	end
	for i = 1, #LOG_WINDOWS do
		fn(FindWindowByName(LOG_WINDOWS[i].name))
	end
end

local function ParkAll()
	if parking or not IsEnabled() then
		return
	end
	parking = true
	SetBlizzardDockShown(false)
	EachManagedFrame(ParkBlizzardFrame)
	PlaceEditBox()
	parking = false
end

local function ApplyFont()
	local size = SplitChatDB.fontSize or DEFAULT_FONT
	local file = FontPath()
	if ChatFontNormal and ChatFontNormal.SetFont then
		ChatFontNormal:SetFont(file, size, FontFlags(ChatFontNormal))
	end
	for i = 1, MaxWindowCount() do
		local frame = _G["ChatFrame" .. i]
		if frame and frame.SetFont then
			frame:SetFont(file, size, FontFlags(frame))
		end
	end
	for i = 1, #commEntries do
		ApplyFontToSMF(commEntries[i].display)
	end
	for i = 1, #logEntries do
		ApplyFontToSMF(logEntries[i].display)
	end
	PlaceEditBox()
end

local function CreatePanel(name, extraBottom)
	local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	panel:SetFrameStrata("MEDIUM")
	panel:EnableMouse(false)
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:SetResizable(true)
	if panel.SetResizeBounds then
		panel:SetResizeBounds(CHAT_FRAME_MIN_WIDTH or 296, 180, 900, 700)
	end
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	panel:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
	panel:SetBackdropBorderColor(0.18, 0.18, 0.2, 0.9)

	local well = CreateFrame("Frame", nil, panel)
	well:SetPoint("TOPLEFT", PAD, -(HEADER + 2))
	well:SetPoint("BOTTOMRIGHT", -PAD, extraBottom or PAD)
	panel.well = well

	local grip = CreateFrame("Button", nil, panel)
	grip:SetSize(GRIP_WIDTH, 18)
	grip:SetPoint("TOPRIGHT", -18, -4)
	grip:SetNormalFontObject("GameFontDisableSmall")
	grip:SetHighlightFontObject("GameFontHighlightSmall")
	grip:SetText("Move")
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", function()
		if not IsLocked() then
			panel:StartMoving()
		end
	end)
	grip:SetScript("OnDragStop", function()
		panel:StopMovingOrSizing()
		if panel.saveKey then
			SavePanel(panel, panel.saveKey)
		end
	end)
	panel.grip = grip

	local filters = CreateFrame("Button", nil, panel)
	filters:SetSize(56, 18)
	filters:SetPoint("TOPRIGHT", -78, -4)
	filters:SetNormalFontObject("GameFontDisableSmall")
	filters:SetHighlightFontObject("GameFontHighlightSmall")
	filters:SetText("Filters")
	filters:SetScript("OnClick", function()
		OpenChatConfig(panel.getSelectedFrame and panel.getSelectedFrame() or ChatFrame1)
	end)
	panel.filters = filters

	local resize = CreateFrame("Button", nil, panel)
	resize:SetSize(16, 16)
	resize:SetPoint("BOTTOMRIGHT", -2, 2)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resize:SetScript("OnMouseDown", function()
		if not IsLocked() then
			panel:StartSizing("BOTTOMRIGHT")
		end
	end)
	resize:SetScript("OnMouseUp", function()
		panel:StopMovingOrSizing()
		if panel.saveKey then
			SavePanel(panel, panel.saveKey)
		end
	end)
	panel.resize = resize
	return panel
end

local function ShowPanels(shown)
	if leftPanel then
		leftPanel:SetShown(shown)
	end
	if rightPanel then
		rightPanel:SetShown(shown)
	end
end

local function RestoreBlizzard()
	SetBlizzardDockShown(true)
	RestoreEditBox()
	EachManagedFrame(function(frame)
		if not frame then
			return
		end
		frame:SetParent(UIParent)
		frame:SetAlpha(1)
		if frame.EnableMouse then
			frame:EnableMouse(true)
		end
		frame:SetClampedToScreen(true)
		if frame.SetToplevel then
			frame:SetToplevel(true)
		end
		SetChatArtShown(frame, true)
		frame:Show()
		if FCF_RestorePositionAndDimensions then
			FCF_RestorePositionAndDimensions(frame)
		end
	end)
	if FCF_DockUpdate then
		FCF_DockUpdate()
	end
end

local function EnableAddon(enabled)
	SplitChatDB.enabled = enabled
	ShowPanels(enabled)
	if enabled then
		EnableClassColors()
		ApplyChatLayout(false)
		BuildDisplays()
		BuildCommTabs()
		BuildLogTabs()
		ApplyFont()
		SelectComm(SplitChatDB.leftTab or "General")
		SelectLog(SplitChatDB.rightTab or "Combat")
		SetPanelsLocked(IsLocked())
		ParkAll()
	else
		RestoreBlizzard()
	end
end

local function CreatePanels()
	if leftPanel then
		return
	end
	leftPanel = CreatePanel("SplitChatLeft", EDIT_PAD)
	leftPanel.saveKey = "left"
	leftPanel.getSelectedFrame = function()
		return SelectedBlizzardFrame()
	end

	rightPanel = CreatePanel("SplitChatRight", PAD)
	rightPanel.saveKey = "right"
	rightPanel.getSelectedFrame = function()
		for i = 1, #logEntries do
			if logEntries[i].name == selectedLog then
				return logEntries[i].source
			end
		end
		return ChatFrame2
	end

	PlacePanel(leftPanel, "left", "BOTTOMLEFT", 20)
	PlacePanel(rightPanel, "right", "BOTTOMRIGHT", -20)
end

local function HookBlizzard()
	if hooked then
		return
	end
	hooked = true
	if not hooksecurefunc then
		return
	end
	local function Repark()
		if IsEnabled() then
			C_Timer.After(0, ParkAll)
		end
	end
	hooksecurefunc("FloatingChatFrame_Update", Repark)
	if FCF_RestorePositionAndDimensions then
		hooksecurefunc("FCF_RestorePositionAndDimensions", Repark)
	end
	if FCF_FadeInChatFrame then
		hooksecurefunc("FCF_FadeInChatFrame", function(chatFrame)
			if IsEnabled() then
				ParkBlizzardFrame(chatFrame)
				PlaceEditBox()
			end
		end)
	end
	if EditModeSystemMixin and EditModeSystemMixin.ApplySystemAnchor then
		hooksecurefunc(EditModeSystemMixin, "ApplySystemAnchor", function(self)
			if IsEnabled() and self == ChatFrame1 then
				ParkBlizzardFrame(self)
				PlaceEditBox()
			end
		end)
	end
end

local function FaceListText()
	return table.concat(FONT_FACE_ORDER, " | ")
end

local function SizeListText()
	return "12 | 14 | 16 | 18 | 20 | 24 | 27"
end

local function StatusText()
	local face = CanonicalFace(SplitChatDB.fontFace) or DEFAULT_FACE
	return "chat " .. BoolText(IsEnabled()) .. "  locked " .. BoolText(IsLocked()) .. "  font " .. face .. " " .. tostring(SplitChatDB.fontSize)
end

local function PrintStatus()
	Print(StatusText())
end

local function PrintMenu()
	Print("/sc on | off | status")
	print("/sc lock | unlock")
	print("/sc font " .. FaceListText())
	print("/sc font " .. SizeListText())
	print("/sc reset")
	print("/sc filters   (or right-click a tab)")
	PrintStatus()
end

local function PrintFontHelp()
	Print("faces: " .. FaceListText() .. "  (arial is the default chat face)")
	print("sizes: " .. SizeListText())
	PrintStatus()
end

local function SetFontFromSlash(rest)
	local first, second = string.match(rest, "^(%S+)%s*(%S*)$")
	local size
	local face
	local function TakeToken(token)
		if not token or token == "" then
			return true
		end
		if FONT_FACES[token] then
			face = CanonicalFace(token)
			return true
		end
		local asNumber = tonumber(token)
		if asNumber then
			if not FONT_SIZES[asNumber] then
				Print("size must be " .. SizeListText())
				return false
			end
			size = asNumber
			return true
		end
		Print("unknown face '" .. token .. "'. Use: " .. FaceListText())
		return false
	end
	if not TakeToken(first) or not TakeToken(second) then
		return
	end
	if not size and not face then
		PrintFontHelp()
		return
	end
	if size then
		SplitChatDB.fontSize = size
	end
	if face then
		SplitChatDB.fontFace = face
	end
	ApplyFont()
	Print((CanonicalFace(SplitChatDB.fontFace) or DEFAULT_FACE) .. " " .. tostring(SplitChatDB.fontSize))
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "" then
		PrintMenu()
		return
	end
	if msg == "status" then
		PrintStatus()
		return
	end
	if msg == "on" then
		EnableAddon(true)
		Print("ON")
		return
	end
	if msg == "off" then
		EnableAddon(false)
		Print("OFF")
		return
	end
	if msg == "lock" then
		SplitChatDB.locked = true
		SetPanelsLocked(true)
		Print("locked")
		return
	end
	if msg == "unlock" then
		SplitChatDB.locked = false
		SetPanelsLocked(false)
		Print("unlocked")
		return
	end
	if msg == "reset" then
		ApplyChatLayout(true)
		BuildDisplays()
		BuildCommTabs()
		BuildLogTabs()
		ApplyFont()
		SelectComm(SplitChatDB.leftTab or "General")
		SelectLog(SplitChatDB.rightTab or "Combat")
		ParkAll()
		Print("layout reset")
		return
	end
	if msg == "filters" or msg == "filter" then
		OpenChatConfig(SelectedBlizzardFrame())
		return
	end
	if msg == "font" or msg == "fonts" then
		PrintFontHelp()
		return
	end
	local fontRest = string.match(msg, "^font%s+(.+)$")
	if fontRest then
		SetFontFromSlash(fontRest)
		return
	end
	PrintMenu()
end

local function StartIfNeeded()
	InitDB()
	CreatePanels()
	HookBlizzard()
	if not IsEnabled() then
		ShowPanels(false)
		return
	end
	if not layoutReady then
		layoutReady = true
		EnableAddon(true)
	else
		ParkAll()
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		StartIfNeeded()
		Print("loaded. Type /sc for the menu.")
		return
	end
	if event == "CHANNEL_UI_UPDATE" then
		if IsEnabled() then
			AddJoinedChannels(ChatFrame1)
		end
		return
	end
	StartIfNeeded()
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
frame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
frame:RegisterEvent("CHANNEL_UI_UPDATE")

SLASH_SPLITCHAT1 = "/sc"
SLASH_SPLITCHAT2 = "/splitchat"
SlashCmdList["SPLITCHAT"] = HandleSlash
