local addonName, ns = ...

local PREFIX = "|cffffcc66OldManQuester|r"

local FRAME_SCALE = 1.4
local FONT_SCALE = 1.0
local BLIZZARD_GOSSIP_WRAP = 270
local worldMapOrigScale
local worldMapCursorFixed

local frameSizes = {}
local fontOriginals = {}
local widthOriginals = {}
local hooked = {}
local applying = false

local WRAP_NAMES = {
	"QuestInfoDescriptionText",
	"QuestInfoObjectivesText",
	"QuestInfoRewardText",
	"QuestInfoGroupSize",
	"QuestInfoTitleHeader",
	"QuestInfoDescriptionHeader",
	"QuestInfoObjectivesHeader",
	"QuestInfoRewardsHeader",
	"QuestInfoItemChooseText",
	"QuestInfoItemReceiveText",
	"QuestInfoSpellLearnText",
	"QuestInfoXPFrameReceiveText",
	"QuestProgressText",
	"QuestProgressTitleText",
	"QuestProgressRequiredItemsText",
	"GreetingText",
	"CurrentQuestsText",
	"AvailableQuestsText",
}

local QUEST_PANELS = {
	"QuestFrameDetailPanel",
	"QuestFrameProgressPanel",
	"QuestFrameRewardPanel",
	"QuestFrameGreetingPanel",
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

local function IsEnabled()
	return OldManQuesterDB and OldManQuesterDB.enabled
end

ns.FRAME_SCALE = FRAME_SCALE
ns.IsEnabled = IsEnabled

local function IsTrackerEnabled()
	return IsEnabled() and OldManQuesterDB and OldManQuesterDB.trackerDialog
end

local function StatusText()
	return BoolText(IsEnabled())
end

local function Named(name)
	return _G[name]
end

local function IsUnder(frame, ancestor)
	if not frame or not ancestor then
		return false
	end
	local current = frame
	local hops = 0
	while current and hops < 30 do
		if current == ancestor then
			return true
		end
		if not current.GetParent then
			return false
		end
		current = current:GetParent()
		hops = hops + 1
	end
	return false
end

local function SnapshotSize(frame)
	if not frame or frameSizes[frame] then
		return
	end
	frameSizes[frame] = {
		width = frame:GetWidth(),
		height = frame:GetHeight(),
		scale = frame:GetScale() or 1,
	}
end

local function SnapshotFont(fontString)
	if not fontString or fontOriginals[fontString] or not fontString.GetFont then
		return
	end
	local file, size, flags = fontString:GetFont()
	if file and size then
		fontOriginals[fontString] = {
			file = file,
			size = size,
			flags = flags,
		}
	end
end

local function ApplyFont(fontString)
	if not fontString then
		return
	end
	SnapshotFont(fontString)
	local orig = fontOriginals[fontString]
	if not orig then
		return
	end
	if IsEnabled() then
		fontString:SetFont(orig.file, orig.size * FONT_SCALE, orig.flags)
	else
		fontString:SetFont(orig.file, orig.size, orig.flags)
	end
end

local function RestoreFont(fontString)
	local orig = fontOriginals[fontString]
	if orig then
		fontString:SetFont(orig.file, orig.size, orig.flags)
	end
end

local function RestoreWidth(region)
	if region and widthOriginals[region] then
		region:SetWidth(widthOriginals[region])
	end
end

local function ForEachFontString(frame, callback, seen, depth)
	if not frame or (seen and seen[frame]) or (depth and depth > 25) then
		return
	end
	seen = seen or {}
	seen[frame] = true
	depth = depth or 0

	if frame.GetObjectType then
		local okType, objectType = pcall(frame.GetObjectType, frame)
		if okType and objectType == "FontString" then
			callback(frame)
			return
		end
	end

	if frame.GetFontString then
		local ok, fontString = pcall(frame.GetFontString, frame)
		if ok and fontString then
			callback(fontString)
		end
	end

	if frame.GetRegions then
		local ok, regions = pcall(function()
			return { frame:GetRegions() }
		end)
		if ok and regions then
			for i = 1, #regions do
				local region = regions[i]
				if region and region.GetObjectType then
					local okType, objectType = pcall(region.GetObjectType, region)
					if okType and objectType == "FontString" then
						callback(region)
					end
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
				ForEachFontString(children[i], callback, seen, depth + 1)
			end
		end
	end
end

local function ApplyFontsOnFrame(frame)
	if not frame then
		return
	end
	ForEachFontString(frame, ApplyFont)
end

local function RestoreNamedWraps()
	for i = 1, #WRAP_NAMES do
		local fontString = Named(WRAP_NAMES[i])
		if fontString then
			RestoreFont(fontString)
			RestoreWidth(fontString)
		end
	end
end

local function ApplyDialogScale(frame)
	if not frame then
		return
	end
	SnapshotSize(frame)
	local orig = frameSizes[frame]
	if not orig then
		return
	end
	if IsEnabled() then
		frame:SetScale(FRAME_SCALE)
		frame:SetSize(orig.width, orig.height)
		if frame.SetAttribute then
			frame:SetAttribute("UIPanelLayout-width", orig.width * FRAME_SCALE)
			frame:SetAttribute("UIPanelLayout-height", orig.height * FRAME_SCALE)
		end
	else
		frame:SetScale(orig.scale or 1)
		frame:SetSize(orig.width, orig.height)
		if frame.SetAttribute then
			frame:SetAttribute("UIPanelLayout-width", orig.width)
			frame:SetAttribute("UIPanelLayout-height", orig.height)
		end
	end
end

local function SnapshotTargets()
	SnapshotSize(QuestFrame)
	SnapshotSize(GossipFrame)
	SnapshotSize(CharacterFrame)
end

local function ApplyFrameSizes()
	SnapshotTargets()
	ApplyDialogScale(QuestFrame)
	ApplyDialogScale(GossipFrame)
	if ns.ApplyCharacterWindow then
		ns.ApplyCharacterWindow()
	end
end

local function MapIsMaximized()
	return WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized()
end

local function FixWorldMapCursor()
	if worldMapCursorFixed or not WorldMapFrame or not WorldMapFrame.ScrollContainer then
		return
	end
	worldMapCursorFixed = true
	-- Extra WorldMapFrame scale is missed by the default cursor math.
	-- https://warcraft.wiki.gg/wiki/API_GetCursorPosition
	-- https://warcraft.wiki.gg/wiki/API_Region_GetEffectiveScale
	WorldMapFrame.ScrollContainer.GetCursorPosition = function(scroll)
		local x, y = GetCursorPosition()
		local scale = scroll:GetEffectiveScale()
		return x / scale, y / scale
	end
end

local function ApplyWorldMapScale()
	if not WorldMapFrame then
		return
	end
	if worldMapOrigScale == nil then
		worldMapOrigScale = WorldMapFrame:GetScale() or 1
	end
	FixWorldMapCursor()
	-- https://warcraft.wiki.gg/wiki/API_Region_SetScale
	if IsEnabled() and not MapIsMaximized() then
		WorldMapFrame:SetScale(FRAME_SCALE)
	else
		WorldMapFrame:SetScale(worldMapOrigScale)
	end
end

local function ApplyAll()
	if applying then
		return
	end
	applying = true
	ApplyFrameSizes()
	ApplyWorldMapScale()
	ApplyFontsOnFrame(QuestFrame)
	ApplyFontsOnFrame(GossipFrame)
	ApplyFontsOnFrame(CharacterFrame)
	if not IsEnabled() then
		RestoreNamedWraps()
	end
	applying = false
end

local function RefreshOpenDialogs()
	if GossipFrame and GossipFrame:IsShown() and GossipFrame.Update then
		GossipFrame:Update()
	end
	for i = 1, #QUEST_PANELS do
		local panel = Named(QUEST_PANELS[i])
		if panel and panel:IsShown() then
			panel:Hide()
			panel:Show()
		end
	end
end

local function OnGossipGreetingSetup(self)
	if not self or not self.GreetingText then
		return
	end
	ApplyFont(self.GreetingText)
	self.GreetingText:SetWidth(BLIZZARD_GOSSIP_WRAP)
	self:SetSize(BLIZZARD_GOSSIP_WRAP, self.GreetingText:GetHeight())
end

local function OnGossipButtonSetup(self)
	if not self then
		return
	end
	local fontString = self.GetFontString and self:GetFontString()
	if fontString then
		ApplyFont(fontString)
	end
	if self.Resize then
		self:Resize()
	end
end

local function OnDialogShow()
	if applying then
		return
	end
	ApplyAll()
end

local function OnQuestFrameHide()
	RestoreNamedWraps()
end

local TRACKER_MODULE_NAMES = {
	"QuestObjectiveTracker",
	"CampaignQuestObjectiveTracker",
	"AdventureObjectiveTracker",
	"AchievementObjectiveTracker",
	"BonusObjectiveTracker",
	"WorldQuestObjectiveTracker",
	"ScenarioObjectiveTracker",
	"ProfessionsRecipeTracker",
	"MonthlyActivitiesObjectiveTracker",
}

local trackerDialog
local headerBgOriginal = {}
local trackerOrig = {}
local trackerFader

local TRACKER_WIDTH = 200
local TRACKER_IDLE_ALPHA = 0.4

local function EachTrackerHeader(callback)
	if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header then
		callback(ObjectiveTrackerFrame.Header)
	end
	if ObjectiveTrackerFrame and ObjectiveTrackerFrame.ForEachModule then
		pcall(function()
			ObjectiveTrackerFrame:ForEachModule(function(module)
				if module and module.Header then
					callback(module.Header)
				end
			end)
		end)
	end
	for i = 1, #TRACKER_MODULE_NAMES do
		local module = Named(TRACKER_MODULE_NAMES[i])
		if module and module.Header then
			callback(module.Header)
		end
	end
end

local function SetTrackerHeaderArtShown(shown)
	EachTrackerHeader(function(header)
		local bg = header.Background
		if not bg then
			return
		end
		if headerBgOriginal[bg] == nil then
			headerBgOriginal[bg] = bg:IsShown()
		end
		if shown then
			bg:SetShown(headerBgOriginal[bg])
		else
			bg:Hide()
		end
	end)
end

local function HideTrackerArt(frame)
	if not frame then
		return
	end
	local art = {
		frame.NineSlice,
		frame.Background,
		frame.Bg,
		frame.Border,
	}
	for i = 1, #art do
		if art[i] then
			art[i]:Hide()
		end
	end
end

local function EnsureTrackerFader()
	if trackerFader then
		return
	end
	trackerFader = CreateFrame("Frame")
	trackerFader.elapsed = 0
	trackerFader:SetScript("OnUpdate", function(self, elapsed)
		if not IsTrackerEnabled() or not ObjectiveTrackerFrame or not ObjectiveTrackerFrame:IsShown() then
			return
		end
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < 0.12 then
			return
		end
		self.elapsed = 0
		if ObjectiveTrackerFrame:IsMouseOver() then
			ObjectiveTrackerFrame:SetAlpha(1)
		else
			ObjectiveTrackerFrame:SetAlpha(TRACKER_IDLE_ALPHA)
		end
	end)
end

local function ApplyTrackerDialog()
	if not ObjectiveTrackerFrame then
		return
	end
	if trackerDialog then
		trackerDialog:Hide()
	end
	if IsTrackerEnabled() and ObjectiveTrackerFrame:IsShown() then
		if trackerOrig.width == nil then
			trackerOrig.width = ObjectiveTrackerFrame:GetWidth()
			trackerOrig.alpha = ObjectiveTrackerFrame:GetAlpha()
		end
		ObjectiveTrackerFrame:SetWidth(TRACKER_WIDTH)
		HideTrackerArt(ObjectiveTrackerFrame)
		SetTrackerHeaderArtShown(false)
		EnsureTrackerFader()
	else
		if trackerOrig.width then
			ObjectiveTrackerFrame:SetWidth(trackerOrig.width)
		end
		if trackerOrig.alpha then
			ObjectiveTrackerFrame:SetAlpha(trackerOrig.alpha)
		else
			ObjectiveTrackerFrame:SetAlpha(1)
		end
		SetTrackerHeaderArtShown(true)
	end
end

local function HookOnce(key, tryHook)
	if hooked[key] then
		return
	end
	if tryHook() then
		hooked[key] = true
	end
end

local function HookMixinSetup(key, mixin, handler)
	HookOnce(key, function()
		if not mixin or not mixin.Setup then
			return false
		end
		hooksecurefunc(mixin, "Setup", handler)
		return true
	end)
end

local function InstallHooks()
	HookMixinSetup("gossipGreeting", GossipGreetingTextMixin, OnGossipGreetingSetup)
	HookMixinSetup("gossipOption", GossipOptionButtonMixin, OnGossipButtonSetup)
	HookMixinSetup("gossipAvailable", GossipSharedAvailableQuestButtonMixin, OnGossipButtonSetup)
	HookMixinSetup("gossipActive", GossipSharedActiveQuestButtonMixin, OnGossipButtonSetup)
	HookMixinSetup("gossipAvailableMain", GossipAvailableQuestButtonMixin, OnGossipButtonSetup)
	HookMixinSetup("gossipActiveMain", GossipActiveQuestButtonMixin, OnGossipButtonSetup)

	HookOnce("questInfo", function()
		if type(QuestInfo_Display) ~= "function" then
			return false
		end
		hooksecurefunc("QuestInfo_Display", function(_, parentFrame)
			if not IsEnabled() or not QuestFrame or not IsUnder(parentFrame, QuestFrame) then
				return
			end
			ApplyFontsOnFrame(QuestInfoFrame)
			ApplyFontsOnFrame(parentFrame)
		end)
		return true
	end)

	HookOnce("questGreeting", function()
		if type(QuestFrameGreetingPanel_OnShow) ~= "function" then
			return false
		end
		hooksecurefunc("QuestFrameGreetingPanel_OnShow", function()
			if not IsEnabled() then
				return
			end
			ApplyFontsOnFrame(QuestFrameGreetingPanel)
		end)
		return true
	end)

	HookOnce("questProgress", function()
		if type(QuestFrameProgressPanel_OnShow) ~= "function" then
			return false
		end
		hooksecurefunc("QuestFrameProgressPanel_OnShow", function()
			if not IsEnabled() then
				return
			end
			ApplyFontsOnFrame(QuestFrameProgressPanel)
		end)
		return true
	end)

	HookOnce("questFrameShow", function()
		if not QuestFrame then
			return false
		end
		QuestFrame:HookScript("OnShow", OnDialogShow)
		QuestFrame:HookScript("OnHide", OnQuestFrameHide)
		return true
	end)

	HookOnce("gossipFrameShow", function()
		if not GossipFrame then
			return false
		end
		GossipFrame:HookScript("OnShow", OnDialogShow)
		return true
	end)

	HookOnce("characterFrameShow", function()
		if not CharacterFrame or not ns.ApplyCharacterWindow then
			return false
		end
		ns.ApplyCharacterWindow()
		return true
	end)

	HookOnce("worldMapShow", function()
		if not WorldMapFrame then
			return false
		end
		WorldMapFrame:HookScript("OnShow", ApplyWorldMapScale)
		if WorldMapFrame.SynchronizeDisplayState then
			hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", ApplyWorldMapScale)
		end
		ApplyWorldMapScale()
		return true
	end)

	HookOnce("trackerShow", function()
		if not ObjectiveTrackerFrame then
			return false
		end
		ObjectiveTrackerFrame:HookScript("OnShow", ApplyTrackerDialog)
		ObjectiveTrackerFrame:HookScript("OnHide", ApplyTrackerDialog)
		ApplyTrackerDialog()
		return true
	end)

	HookOnce("trackerUpdate", function()
		if ObjectiveTrackerFrameMixin and ObjectiveTrackerFrameMixin.Update then
			hooksecurefunc(ObjectiveTrackerFrameMixin, "Update", ApplyTrackerDialog)
			return true
		end
		if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
			hooksecurefunc(ObjectiveTrackerFrame, "Update", ApplyTrackerDialog)
			return true
		end
		return false
	end)
end

local function InitDB()
	if type(OldManQuesterDB) ~= "table" then
		OldManQuesterDB = {}
	end
	if OldManQuesterDB.enabled == nil then
		OldManQuesterDB.enabled = true
	end
	if OldManQuesterDB.trackerDialog == nil then
		OldManQuesterDB.trackerDialog = true
	end
end

local function PrintStatus()
	Print("dialog " .. StatusText()
		.. "  tracker " .. BoolText(IsTrackerEnabled()))
end

local function SetEnabled(enabled)
	OldManQuesterDB.enabled = enabled
	ApplyAll()
	RefreshOpenDialogs()
	ApplyTrackerDialog()
	PrintStatus()
end

local function ParseOnOff(text)
	if text == "on" then
		return true
	end
	if text == "off" then
		return false
	end
	return nil
end

local function SetTrackerEnabled(enabled)
	OldManQuesterDB.trackerDialog = enabled
	ApplyTrackerDialog()
	Print("tracker " .. BoolText(IsTrackerEnabled()))
	if enabled and not IsEnabled() then
		Print("Turn the addon on with /omq on to use the compact tracker.")
	end
end

local function PrintMenu()
	Print("/omq on | off | status")
	print("/omq tracker on | off")
	PrintStatus()
end

local function HandleSlash(msg)
	msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
	if msg == "on" then
		SetEnabled(true)
		return
	end
	if msg == "off" then
		SetEnabled(false)
		return
	end
	if msg == "status" then
		PrintStatus()
		return
	end
	local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
	if cmd == "tracker" then
		local value = ParseOnOff(rest)
		if value == nil then
			Print("/omq tracker on | off")
			return
		end
		SetTrackerEnabled(value)
		return
	end
	PrintMenu()
end

local function TryStart()
	InitDB()
	InstallHooks()
	SnapshotTargets()
	if IsEnabled() then
		ApplyAll()
	end
	ApplyTrackerDialog()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedName)
	if event == "ADDON_LOADED" then
		if loadedName == addonName then
			InitDB()
		end
		InstallHooks()
		if loadedName == "Blizzard_ObjectiveTracker" then
			ApplyTrackerDialog()
		end
	elseif event == "PLAYER_LOGIN" then
		TryStart()
		Print("loaded. Type /omq for the menu.")
	end
end)

SLASH_OLDMANQUESTER1 = "/omq"
SLASH_OLDMANQUESTER2 = "/oldmanquester"
SlashCmdList["OLDMANQUESTER"] = HandleSlash
