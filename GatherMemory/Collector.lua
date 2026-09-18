local _, ns = ...

local SPELL_KIND = {}
local activeKind
local activeName
local foundTarget

local function RememberSpell(spellID, kind)
	SPELL_KIND[spellID] = kind
	local name = ns.SpellName(spellID)
	if name then
		SPELL_KIND[name] = kind
	end
end

local function PublicText(value)
	if value == nil or value == "" then
		return nil
	end
	if issecretvalue then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret then
			return nil
		end
	end
	return value
end

local function TooltipNodeName()
	local fontString = _G.GameTooltipTextLeft1
	if not fontString or not fontString.GetText then
		return nil
	end
	return PublicText(fontString:GetText())
end

local function KindForSpell(spellID, spellName)
	return SPELL_KIND[spellID] or SPELL_KIND[spellName]
end

local function SaveNode(name, kind)
	name = PublicText(name)
	if not name or not kind then
		return
	end
	if name == ns.SpellName(2366) or name == ns.SpellName(2575) or name == ns.SpellName(3365) or name == ns.SpellName(7620) then
		return
	end
	if string.lower(name) == "fishing bobber" then
		return
	end
	local catalogKind = ns.GuessKindFromName(name)
	if catalogKind then
		kind = catalogKind
	end
	-- Opening is used for quest objects on the ground; only keep real chests.
	if kind == "chest" and catalogKind ~= "chest" then
		return
	end
	-- Fishing casts in open water are not nodes; only keep schools and wreckage.
	if kind == "fish" and catalogKind ~= "fish" then
		return
	end
	foundTarget = true
	ns.AddNode(name, kind)
end

local function TryWorldTarget()
	if foundTarget or not activeKind then
		return
	end
	if MinimapCluster and MinimapCluster.IsMouseOver and MinimapCluster:IsMouseOver() then
		return
	end
	local name = TooltipNodeName()
	if name and name ~= activeName then
		SaveNode(name, activeKind)
	end
end

function ns.InitCollector()
	RememberSpell(2366, "herb") -- Herb Gathering
	RememberSpell(2575, "ore") -- Mining
	RememberSpell(3365, "chest") -- Opening
	RememberSpell(22810, "chest") -- Opening - No Text
	RememberSpell(1804, "chest") -- Pick Lock
	RememberSpell(7620, "fish") -- Fishing

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	frame:RegisterEvent("CURSOR_CHANGED")
	frame:RegisterEvent("UI_ERROR_MESSAGE")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_SPELLCAST_SENT" then
			local unit, target, _, spellID = ...
			if unit ~= "player" then
				return
			end
			foundTarget = false
			local spellName = ns.SpellName(spellID)
			local kind = KindForSpell(spellID, spellName)
			if not kind then
				activeKind = nil
				activeName = nil
				return
			end
			activeKind = kind
			activeName = spellName
			target = PublicText(target)
			if target and target ~= "" and target ~= spellName then
				SaveNode(target, kind)
			else
				TryWorldTarget()
			end
		elseif event == "UNIT_SPELLCAST_STOP" then
			local unit = ...
			if unit == "player" then
				TryWorldTarget()
			end
		elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
			local unit = ...
			if unit == "player" then
				activeKind = nil
				activeName = nil
				foundTarget = false
			end
		elseif event == "CURSOR_CHANGED" then
			TryWorldTarget()
		elseif event == "UI_ERROR_MESSAGE" then
			local arg1, arg2 = ...
			local message = PublicText(arg2 or arg1) or ""
			local name = TooltipNodeName()
			if not name then
				return
			end
			local herbName = ns.SpellName(2366) or "Herb"
			local herbSkill = ns.SpellName(9134) or "Herbalism"
			local mineName = ns.SpellName(2575) or "Mining"
			local openName = ns.SpellName(3365) or "Opening"
			local pickName = ns.SpellName(1804) or "Pick Lock"
			local fishName = ns.SpellName(7620) or "Fishing"
			if string.find(message, mineName, 1, true) then
				SaveNode(name, "ore")
			elseif string.find(message, herbName, 1, true) or string.find(message, herbSkill, 1, true) then
				SaveNode(name, "herb")
			elseif string.find(message, openName, 1, true) or string.find(message, pickName, 1, true) then
				SaveNode(name, "chest")
			elseif string.find(message, fishName, 1, true) then
				SaveNode(name, "fish")
			end
		end
	end)
end
