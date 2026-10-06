local _, ns = ...

local window
local host
local searchBox
local scroll
local content
local columnHeader
local viewButton
local tagMenu
local filterMenu
local filterButton
local minimapButton
local docked = false
local pool = {}
local used = 0
local cardPool = {}
local cardsUsed = 0
local headerPool = {}
local headersUsed = 0
local expandedItems = {}
local refreshing = false
local view = "home"
local selectedName
local HideTagMenu

local CARD_W = 116
local CARD_H = 132
local CARD_GAP = 8
local ART_H = 64

local PAD = 12
local ROW_H = 22
local ICON = 18
local COLUMN_GAP = 4
local COLUMN_RIGHT = 2
local COLUMNS = {
	{ key = "tag", label = "Tag", width = 22 },
	{ key = "qty", label = "Qty", width = 40 },
	{ key = "seen", label = "Seen", width = 56 },
	{ key = "rate", label = "Rate", width = 40 },
}

local TAG_CHOICES = {
	{ id = "quest", label = "Quest" },
	{ id = "crafting", label = "Crafting" },
	{ id = "equipment", label = "Equipment" },
	{ id = "junk", label = "Junk" },
}

local TAG_SHORT = {
	quest = "Q",
	crafting = "C",
	equipment = "E",
	junk = "J",
}

-- New filter toggles are another row in this list.
local FILTERS = {
	{ id = "crafting", label = "Crafting", icon = "Interface\\Icons\\INV_Misc_ArmorKit_17" },
	{ id = "quest", label = "Quest", icon = "Interface\\Icons\\INV_Misc_Note_01" },
	{ id = "equipment", label = "Gear", icon = "Interface\\Icons\\INV_Chest_Chain" },
	{ id = "green", label = "Green Items", quality = 2, icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01" },
	{ id = "rare", label = "Rare Items", quality = 3, icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01" },
	{ id = "epic", label = "Epic Items", quality = 4, icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01" },
	{ id = "junk", label = "Junk", quality = 0, icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

local function Trim(text)
	return string.lower(string.match(text or "", "^%s*(.-)%s*$") or "")
end

function ns.GetSearchQuery()
	if not searchBox or not searchBox.GetText then
		return ""
	end
	return Trim(searchBox:GetText())
end

local function SavePosition()
	if not window then
		return
	end
	local point, _, _, x, y = window:GetPoint(1)
	if point then
		PhatLewtDbDB.point = point
		PhatLewtDbDB.x = x
		PhatLewtDbDB.y = y
	end
end

local function RestorePosition()
	if not window then
		return
	end
	window:ClearAllPoints()
	if PhatLewtDbDB.point then
		window:SetPoint(PhatLewtDbDB.point, UIParent, PhatLewtDbDB.point, PhatLewtDbDB.x or 0, PhatLewtDbDB.y or 0)
	else
		window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

local function PlayClick()
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and PlaySound then
		pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

local function SetWindowTitle(text)
	if not window then
		return
	end
	if window.SetTitle then
		window:SetTitle(text)
	elseif window.TitleContainer and window.TitleContainer.TitleText then
		window.TitleContainer.TitleText:SetText(text)
	end
end

local function ShowCurrentZone()
	local place = ns.CurrentPlace()
	expandedItems = {}
	if not place then
		view = "home"
		selectedName = nil
		return
	end
	selectedName = place.name
	view = "zone"
end

local function ShowHome()
	view = "home"
	selectedName = nil
	expandedItems = {}
end

local function ZoneTitle(zone)
	local name = zone.name or "Unknown"
	if zone.kind == "dungeon" then
		return name .. " (Dungeon)"
	end
	if zone.kind == "raid" then
		return name .. " (Raid)"
	end
	return name
end

local function ItemScore(item, itemID)
	local tag = ns.GetTag(itemID)
	local quality = item.quality
	if tag == "junk" or quality == 0 then
		return -1
	end
	local score = 100
	if quality == 4 then
		score = 400
	elseif quality == 3 then
		score = 300
	elseif quality == 2 then
		score = 200
	end
	if tag == "crafting" or item.crafting then
		score = score + 40
	end
	if item.reagent then
		score = score + 30
	end
	if tag == "quest" or item.quest then
		score = score + 20
	end
	if tag == "equipment" then
		score = score + 10
	end
	return score
end

local function ItemMatches(item, itemID, query)
	if query == "" then
		return true
	end
	local name = string.lower(item.name or "")
	if string.find(name, query, 1, true) then
		return true
	end
	local tag = ns.GetTag(itemID)
	if tag and string.find(tag, query, 1, true) then
		return true
	end
	if query == "epic" or query == "purple" then
		return item.quality == 4
	end
	if query == "rare" or query == "blue" then
		return item.quality == 3
	end
	if query == "uncommon" or query == "green" then
		return item.quality == 2
	end
	if query == "quest" then
		return tag == "quest" or item.quest
	end
	if query == "crafting" then
		return tag == "crafting" or item.crafting
	end
	if query == "equipment" then
		return tag == "equipment"
	end
	if query == "junk" then
		return tag == "junk" or item.quality == 0
	end
	if query == "reagent" or query == "reagents" then
		return item.reagent and true or false
	end
	return false
end

local function FiltersOn()
	local filters = PhatLewtDbDB and PhatLewtDbDB.filters
	if type(filters) ~= "table" then
		return false
	end
	for i = 1, #FILTERS do
		if filters[FILTERS[i].id] then
			return true
		end
	end
	return false
end

local function ItemHasKind(item, itemID, id)
	local tag = ns.GetTag(itemID)
	if id == "crafting" then
		return (tag == "crafting" or item.crafting) and true or false
	end
	if id == "quest" then
		return (tag == "quest" or item.quest) and true or false
	end
	if id == "equipment" then
		return tag == "equipment"
	end
	if id == "green" then
		return item.quality == 2
	end
	if id == "rare" then
		return item.quality == 3
	end
	if id == "epic" then
		return item.quality == 4
	end
	if id == "junk" then
		return tag == "junk" or item.quality == 0
	end
	return false
end

local function ItemPassesFilters(item, itemID)
	if not FiltersOn() then
		return true
	end
	local filters = PhatLewtDbDB.filters
	for i = 1, #FILTERS do
		local id = FILTERS[i].id
		if filters[id] and ItemHasKind(item, itemID, id) then
			return true
		end
	end
	return false
end

local function MobMatches(mob, query)
	if query == "" then
		return false
	end
	local name = string.lower(mob.name or "")
	return string.find(name, query, 1, true) ~= nil
end

local function SourceRate(source)
	if not source.opens or source.opens < 1 then
		return 0
	end
	return source.count / source.opens
end

local function ZoneItems(zone, query, zoneMatch)
	local byID = {}
	local list = {}
	if type(zone.mobs) ~= "table" then
		return list
	end
	for _, mob in pairs(zone.mobs) do
		if type(mob) == "table" and type(mob.items) == "table" then
			local mobHit = query ~= "" and MobMatches(mob, query)
			for rawID, item in pairs(mob.items) do
				local itemID = ns.PlainNumber(rawID)
				if itemID and type(item) == "table" then
					local show = (query == "" or zoneMatch or mobHit or ItemMatches(item, itemID, query))
						and ItemPassesFilters(item, itemID)
					if show then
						local row = byID[itemID]
						if not row then
							row = {
								itemID = itemID,
								item = item,
								sources = {},
								count = 0,
								quantity = 0,
								opens = 0,
								score = ItemScore(item, itemID),
								name = string.lower(item.name or ""),
							}
							byID[itemID] = row
							list[#list + 1] = row
						elseif item.name and not row.item.name then
							row.item = item
							row.score = ItemScore(item, itemID)
							row.name = string.lower(item.name or "")
						end
						local count = item.count or 0
						local qty = item.quantity or count
						local opens = mob.opens or 0
						row.count = row.count + count
						row.quantity = row.quantity + qty
						row.opens = row.opens + opens
						row.sources[#row.sources + 1] = {
							name = mob.name or "Unknown",
							boss = mob.boss and true or false,
							count = count,
							quantity = qty,
							opens = opens,
						}
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)
	for i = 1, #list do
		table.sort(list[i].sources, function(a, b)
			local aRate = SourceRate(a)
			local bRate = SourceRate(b)
			if aRate ~= bRate then
				return aRate > bRate
			end
			return string.lower(a.name) < string.lower(b.name)
		end)
	end
	return list
end

local GROUP_ORDER = { "world", "dungeon", "raid", "other" }
local GROUP_LABEL = {
	world = "Zones",
	dungeon = "Dungeons",
	raid = "Raids",
	other = "Other",
}

local function Lower(text)
	return string.lower(text or "")
end

local function NamesMatch(a, b)
	if not a or a == "" or not b or b == "" then
		return false
	end
	return Lower(a) == Lower(b)
end

local function PlaceHit(place, name)
	if NamesMatch(place.name, name) then
		return true
	end
	local aliases = place.aliases
	if type(aliases) ~= "table" then
		return false
	end
	for i = 1, #aliases do
		if NamesMatch(aliases[i], name) then
			return true
		end
	end
	return false
end

local function SavedByName()
	local map = {}
	local zones = PhatLewtDbDB and PhatLewtDbDB.zones or {}
	for key, zone in pairs(zones) do
		if type(key) == "string" and type(zone) == "table" and type(zone.name) == "string" then
			local savedName = Lower(zone.name)
			if not map[savedName] then
				map[savedName] = { key = key, zone = zone }
			end
		end
	end
	return map
end

local function SavedForPlace(spec, saved)
	local exact = saved[Lower(spec.name)]
	if exact then
		return exact
	end
	if type(spec.aliases) ~= "table" then
		return nil
	end
	for i = 1, #spec.aliases do
		local match = saved[Lower(spec.aliases[i])]
		if match then
			return match
		end
	end
	return nil
end

local function CollectCards()
	local saved = SavedByName()
	local used = {}
	local place = ns.CurrentPlace()
	local zones = PhatLewtDbDB and PhatLewtDbDB.zones or {}
	local cards = {}
	local list = ns.PLACES or {}
	for i = 1, #list do
		local spec = list[i]
		local match = SavedForPlace(spec, saved)
		local here = place and PlaceHit(spec, place.name)
		local key
		local zone
		if match then
			key = match.key
			zone = match.zone
			used[match.key] = true
		elseif here and place then
			key = place.key
			zone = zones[place.key] or { name = spec.name, kind = spec.kind, mobs = {} }
			used[place.key] = true
		else
			key = "place:" .. Lower(spec.name)
			zone = { name = spec.name, kind = spec.kind, mobs = {} }
		end
		local art = spec.art
		if (type(art) ~= "string" or art == "") and type(ns.PLACE_ART) == "table" then
			art = ns.PLACE_ART[spec.name]
		end
		cards[#cards + 1] = {
			key = key,
			name = spec.name,
			kind = spec.kind,
			aliases = spec.aliases,
			art = art,
			zone = zone,
			here = here and true or false,
			listed = true,
		}
	end
	for key, zone in pairs(zones) do
		if type(key) == "string" and type(zone) == "table" and not used[key] then
			cards[#cards + 1] = {
				key = key,
				name = zone.name or "Unknown",
				kind = zone.kind or "world",
				art = nil,
				zone = zone,
				here = place and key == place.key or false,
				listed = false,
			}
			used[key] = true
		end
	end
	if place and not used[place.key] then
		cards[#cards + 1] = {
			key = place.key,
			name = place.name,
			kind = place.kind,
			art = nil,
			zone = zones[place.key] or { name = place.name, kind = place.kind, mobs = {} },
			here = true,
			listed = false,
		}
	end
	return cards
end

local function CardForName(cards, name)
	if not name then
		return nil
	end
	for i = 1, #cards do
		if PlaceHit(cards[i], name) then
			return cards[i]
		end
	end
	return nil
end

local function SetLineFont(text, size, fontObject)
	if not text:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "") then
		text:SetFontObject(fontObject or "GameFontHighlightSmall")
	end
end

local function ZoneDetail(itemCount)
	if itemCount == 1 then
		return "1 item"
	end
	return itemCount .. " items"
end

local function ItemColumns(item, itemID, opens)
	local count = item.count or 0
	local qty = item.quantity or count
	local rate = ""
	local seen = ""
	if opens and opens > 0 then
		rate = math.floor((count / opens) * 100 + 0.5) .. "%"
		seen = count .. "/" .. opens
	end
	local tag = TAG_SHORT[ns.GetTag(itemID)]
	if not tag then
		if item.quest then
			tag = "Q"
		elseif item.crafting then
			tag = "C"
		elseif item.reagent then
			tag = "R"
		else
			tag = ""
		end
	end
	return rate, seen, "x" .. qty, tag
end

local function HexByte(value)
	local byte = math.floor((value or 1) * 255 + 0.5)
	if byte < 0 then
		byte = 0
	elseif byte > 255 then
		byte = 255
	end
	return string.format("%02x", byte)
end

local function ItemText(item, itemID)
	local name = item.name or ("Item " .. itemID)
	local r, g, b = ns.QualityColor(item.quality)
	local hex = HexByte(r) .. HexByte(g) .. HexByte(b)
	return "|cff" .. hex .. name .. "|r"
end

local function AcquireRow()
	used = used + 1
	local row = pool[used]
	if row then
		row:Show()
		return row
	end
	row = CreateFrame("Button", nil, content)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.arrow = row:CreateTexture(nil, "OVERLAY")
	row.arrow:SetSize(14, 14)
	row.arrow:Hide()
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	SetLineFont(row.name)
	row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.detail:SetJustifyH("RIGHT")
	row.detail:SetWordWrap(false)
	row.detail:SetTextColor(0.72, 0.72, 0.72)
	SetLineFont(row.detail)
	row.cols = {}
	for i = 1, #COLUMNS do
		local spec = COLUMNS[i]
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetJustifyH("RIGHT")
		text:SetWordWrap(false)
		text:SetTextColor(0.78, 0.78, 0.78)
		SetLineFont(text)
		text:Hide()
		row.cols[spec.key] = text
	end
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local highlight = row:GetHighlightTexture()
	if highlight then
		highlight:SetAllPoints()
	end
	row:EnableMouseWheel(true)
	row:SetScript("OnMouseWheel", function(_, delta)
		if not scroll then
			return
		end
		local nextScroll = scroll:GetVerticalScroll() - (delta * (ROW_H * 3))
		local range = scroll:GetVerticalScrollRange()
		if nextScroll < 0 then
			nextScroll = 0
		elseif nextScroll > range then
			nextScroll = range
		end
		scroll:SetVerticalScroll(nextScroll)
	end)
	row:SetScript("OnClick", function(self, button)
		HideTagMenu()
		local payload = self.payload
		if not payload then
			return
		end
		if button == "LeftButton" and payload.kind == "item" then
			local id = payload.zoneKey .. ":" .. payload.itemID
			if expandedItems[id] then
				expandedItems[id] = nil
			else
				expandedItems[id] = true
			end
			ns.RefreshList()
		elseif button == "RightButton" and payload.kind == "item" then
			ns.ShowTagMenu(payload.itemID)
		end
	end)
	row:SetScript("OnEnter", function(self)
		local payload = self.payload
		if not payload or payload.kind ~= "item" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local shown = false
		if payload.itemID and GameTooltip.SetItemByID then
			local ok = pcall(GameTooltip.SetItemByID, GameTooltip, payload.itemID)
			shown = ok
		end
		if not shown and payload.link and GameTooltip.SetHyperlink then
			pcall(GameTooltip.SetHyperlink, GameTooltip, payload.link)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pool[used] = row
	return row
end

local function HideSpareRows()
	for i = used + 1, #pool do
		pool[i]:Hide()
		pool[i].payload = nil
	end
end

local function PlaceRow(row, y, height)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	row:SetHeight(height)
end

local function ItemIcon(item, itemID)
	if item and item.icon then
		return item.icon
	end
	if itemID and C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
		if ok and icon then
			return icon
		end
	end
	return nil
end

local function ShowArrow(row, expanded, indent)
	row.arrow:ClearAllPoints()
	row.arrow:SetPoint("LEFT", indent or 0, 0)
	row.arrow:SetSize(14, 14)
	local hasAtlas = false
	if C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, "bag-arrow")
		hasAtlas = ok and info ~= nil
	end
	if hasAtlas and row.arrow.SetAtlas then
		row.arrow:SetAtlas("bag-arrow")
		if row.arrow.SetRotation then
			if expanded then
				row.arrow:SetRotation(math.pi / 2)
			else
				row.arrow:SetRotation(-math.pi)
			end
		end
	else
		if expanded then
			row.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
		else
			row.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
		end
		row.arrow:SetTexCoord(0.2, 0.8, 0.2, 0.8)
		if row.arrow.SetRotation then
			row.arrow:SetRotation(0)
		end
	end
	row.arrow:Show()
end

local function HideArrow(row)
	if row.arrow then
		row.arrow:Hide()
	end
end

local function ShowIcon(row, icon, indent)
	row.icon:ClearAllPoints()
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("LEFT", indent, 0)
	if icon then
		row.icon:SetTexture(icon)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon:Show()
	else
		row.icon:SetTexture(nil)
		row.icon:Hide()
	end
end

local function HideColumns(row)
	if not row.cols then
		return
	end
	for i = 1, #COLUMNS do
		row.cols[COLUMNS[i].key]:Hide()
	end
end

local function LayoutText(row, left, rightText)
	HideColumns(row)
	row.name:ClearAllPoints()
	row.detail:ClearAllPoints()
	row.name:SetPoint("LEFT", left, 0)
	row.detail:SetPoint("RIGHT", -COLUMN_RIGHT, 0)
	if rightText and rightText ~= "" then
		row.detail:SetText(rightText)
		row.detail:Show()
		row.name:SetPoint("RIGHT", row.detail, "LEFT", -8, 0)
	else
		row.detail:SetText("")
		row.detail:Hide()
		row.name:SetPoint("RIGHT", -COLUMN_RIGHT, 0)
	end
end

local function LayoutColumns(row, left, rate, seen, qty, tag)
	row.detail:Hide()
	local values = {
		rate = rate,
		seen = seen,
		qty = qty,
		tag = tag,
	}
	local cursor = -COLUMN_RIGHT
	local nameRight = cursor
	for i = 1, #COLUMNS do
		local spec = COLUMNS[i]
		local text = row.cols[spec.key]
		text:ClearAllPoints()
		text:SetWidth(spec.width)
		text:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
		text:SetText(values[spec.key] or "")
		text:Show()
		nameRight = cursor - spec.width
		cursor = cursor - spec.width - COLUMN_GAP
	end
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", left, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", nameRight - COLUMN_GAP, 0)
end

local KIND_ICON = {
	world = "Interface\\Icons\\INV_Misc_Map_01",
	dungeon = "Interface\\Icons\\INV_Misc_Key_03",
	raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
}

local function ContentWidth()
	local width = scroll and scroll:GetWidth() or 360
	if width < 40 then
		width = 360
	end
	return width
end

local function AnchorScroll()
	if not scroll or not host then
		return
	end
	local top = -(PAD + 48)
	if view == "home" then
		top = -(PAD + 30)
	end
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, top)
	scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -22, PAD)
end

local function ApplyChrome()
	AnchorScroll()
	if viewButton then
		if view == "home" then
			viewButton:SetText("Here")
		else
			viewButton:SetText("Zones")
		end
	end
	if columnHeader then
		if view == "home" then
			columnHeader:Hide()
		else
			columnHeader:Show()
		end
	end
	if view == "home" then
		SetWindowTitle("PhatLewt")
	end
end

local function HideAllCards()
	cardsUsed = 0
	for i = 1, #cardPool do
		cardPool[i]:Hide()
		cardPool[i].payload = nil
	end
end

local function HideAllHeaders()
	headersUsed = 0
	for i = 1, #headerPool do
		headerPool[i]:Hide()
	end
end

local function HideSpareHeaders()
	for i = headersUsed + 1, #headerPool do
		headerPool[i]:Hide()
	end
end

local function AcquireHeader()
	headersUsed = headersUsed + 1
	local header = headerPool[headersUsed]
	if header then
		header:Show()
		return header
	end
	header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetJustifyH("LEFT")
	header:SetTextColor(1, 0.82, 0)
	headerPool[headersUsed] = header
	return header
end

local function ScrollWheel(_, delta)
	if not scroll then
		return
	end
	local nextScroll = scroll:GetVerticalScroll() - (delta * (ROW_H * 3))
	local range = scroll:GetVerticalScrollRange()
	if nextScroll < 0 then
		nextScroll = 0
	elseif nextScroll > range then
		nextScroll = range
	end
	scroll:SetVerticalScroll(nextScroll)
end

local function ApplyCardArt(card, entry)
	local path = entry.art
	card.art:SetTexCoord(0, 1, 0, 1)
	if type(path) == "string" and path ~= "" then
		local ok = card.art:SetTexture(path)
		if ok ~= false then
			card.art:SetTexCoord(0.02, 0.98, 0.08, 0.82)
			card.art:Show()
			card.icon:Hide()
			return
		end
	end
	card.art:SetTexture("Interface\\QuestFrame\\QuestBG")
	card.art:SetTexCoord(0.04, 0.58, 0.04, 0.42)
	card.art:Show()
	card.icon:SetTexture(KIND_ICON[entry.kind] or "Interface\\Icons\\INV_Misc_QuestionMark")
	card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	card.icon:Show()
end

local function PaintCard(card, entry, count)
	ApplyCardArt(card, entry)
	card.name:SetText(entry.name)
	if entry.here then
		card.name:SetTextColor(0.45, 0.24, 0.02)
		card:SetBackdropBorderColor(1, 0.82, 0, 1)
	else
		card.name:SetTextColor(0.22, 0.1, 0.02)
		card:SetBackdropBorderColor(0.55, 0.42, 0.24, 1)
	end
	local detail = ZoneDetail(count)
	if entry.here then
		detail = "Here · " .. detail
	end
	card.detail:SetText(detail)
	if entry.here then
		card.detail:SetTextColor(0.45, 0.28, 0.05)
	else
		card.detail:SetTextColor(0.35, 0.24, 0.14)
	end
end

local function AcquireCard()
	cardsUsed = cardsUsed + 1
	local card = cardPool[cardsUsed]
	if card then
		card:Show()
		return card
	end
	card = CreateFrame("Button", nil, content, "BackdropTemplate")
	card:SetSize(CARD_W, CARD_H)
	card:RegisterForClicks("LeftButtonUp")
	card:SetBackdrop({
		bgFile = "Interface\\QuestFrame\\QuestBG",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	card:SetBackdropColor(1, 1, 1, 1)
	card.art = card:CreateTexture(nil, "ARTWORK")
	card.art:SetPoint("TOPLEFT", 8, -8)
	card.art:SetSize(CARD_W - 16, ART_H)
	card.icon = card:CreateTexture(nil, "OVERLAY")
	card.icon:SetSize(36, 36)
	card.icon:SetPoint("CENTER", card.art, "CENTER", 0, 0)
	card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.name:SetPoint("TOPLEFT", card.art, "BOTTOMLEFT", 0, -4)
	card.name:SetPoint("TOPRIGHT", card.art, "BOTTOMRIGHT", 0, -4)
	card.name:SetHeight(28)
	card.name:SetJustifyH("CENTER")
	card.name:SetJustifyV("TOP")
	card.name:SetWordWrap(true)
	if card.name.SetMaxLines then
		card.name:SetMaxLines(2)
	end
	SetLineFont(card.name, 11, "GameFontHighlightSmall")
	card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.detail:SetPoint("BOTTOM", 0, 8)
	card.detail:SetWidth(CARD_W - 16)
	card.detail:SetJustifyH("CENTER")
	card.detail:SetWordWrap(false)
	SetLineFont(card.detail, 10, "GameFontDisableSmall")
	card:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local highlight = card:GetHighlightTexture()
	if highlight then
		highlight:SetAllPoints()
	end
	card:EnableMouseWheel(true)
	card:SetScript("OnMouseWheel", ScrollWheel)
	card:SetScript("OnClick", function(self)
		HideTagMenu()
		local payload = self.payload
		if not payload then
			return
		end
		selectedName = payload.name
		view = "zone"
		expandedItems = {}
		PlayClick()
		ns.RefreshList()
		if scroll then
			scroll:SetVerticalScroll(0)
		end
	end)
	card:SetScript("OnEnter", function(self)
		local payload = self.payload
		if not payload then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(payload.name)
		if payload.here then
			GameTooltip:AddLine("You are here", 1, 0.82, 0)
		end
		GameTooltip:Show()
	end)
	card:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	cardPool[cardsUsed] = card
	return card
end

local function CardMatchesQuery(card, query)
	if query == "" then
		return true
	end
	if string.find(Lower(card.name), query, 1, true) then
		return true
	end
	if type(card.aliases) == "table" then
		for i = 1, #card.aliases do
			if string.find(Lower(card.aliases[i]), query, 1, true) then
				return true
			end
		end
	end
	if string.find(Lower(card.kind), query, 1, true) then
		return true
	end
	local label = "other"
	if card.listed and GROUP_LABEL[card.kind] then
		label = GROUP_LABEL[card.kind]
	end
	return string.find(Lower(label), query, 1, true) ~= nil
end

local function GroupOf(card)
	if not card.listed then
		return "other"
	end
	if GROUP_LABEL[card.kind] then
		return card.kind
	end
	return "other"
end

local function NoteRow(y, text)
	local note = AcquireRow()
	note.payload = { kind = "note" }
	PlaceRow(note, y, ROW_H)
	HideArrow(note)
	ShowIcon(note, nil, 0)
	SetLineFont(note.name, 12, "GameFontHighlightSmall")
	note.name:SetTextColor(0.5, 0.5, 0.5)
	note.name:SetText(text)
	LayoutText(note, 2, nil)
	return y + ROW_H
end

local function FillItems(zone, zoneKey, y, query)
	local items = ZoneItems(zone, query, false)
	if #items == 0 then
		local text = "Nothing has dropped here yet."
		if query ~= "" or FiltersOn() then
			text = "No drops match."
		end
		return NoteRow(y, text)
	end
	for n = 1, #items do
		local entryItem = items[n]
		local item = entryItem.item
		local itemKey = zoneKey .. ":" .. entryItem.itemID
		local showSources = expandedItems[itemKey]
		local itemRow = AcquireRow()
		itemRow.payload = {
			kind = "item",
			zoneKey = zoneKey,
			itemID = entryItem.itemID,
			link = item.link,
		}
		PlaceRow(itemRow, y, ROW_H)
		ShowArrow(itemRow, showSources, 2)
		ShowIcon(itemRow, ItemIcon(item, entryItem.itemID), 20)
		SetLineFont(itemRow.name, 12, "GameFontHighlightSmall")
		itemRow.name:SetTextColor(1, 1, 1)
		itemRow.name:SetText(ItemText(item, entryItem.itemID))
		local stats = {
			count = entryItem.count,
			quantity = entryItem.quantity,
			quest = item.quest,
			crafting = item.crafting,
			reagent = item.reagent,
		}
		local rate, seen, qty, tag = ItemColumns(stats, entryItem.itemID, entryItem.opens)
		LayoutColumns(itemRow, 42, rate, seen, qty, tag)
		y = y + ROW_H
		if showSources then
			for s = 1, #entryItem.sources do
				local source = entryItem.sources[s]
				local sourceRow = AcquireRow()
				sourceRow.payload = { kind = "source" }
				PlaceRow(sourceRow, y, ROW_H)
				HideArrow(sourceRow)
				ShowIcon(sourceRow, nil, 0)
				local sourceName = source.name
				SetLineFont(sourceRow.name, 12, "GameFontHighlightSmall")
				if source.boss then
					sourceRow.name:SetTextColor(1, 1, 1)
					sourceName = "|cffff8000" .. sourceName .. "|r"
				else
					sourceRow.name:SetTextColor(0.75, 0.75, 0.75)
				end
				sourceRow.name:SetText(sourceName)
				local sourceStats = {
					count = source.count,
					quantity = source.quantity,
				}
				local sourceRate, sourceSeen, sourceQty = ItemColumns(sourceStats, nil, source.opens)
				LayoutColumns(sourceRow, 42, sourceRate, sourceSeen, sourceQty, "")
				y = y + ROW_H
			end
		end
	end
	return y
end

local function RefreshHome()
	HideAllCards()
	HideAllHeaders()
	used = 0
	local query = ns.GetSearchQuery()
	local filtering = FiltersOn()
	local width = ContentWidth()
	content:SetWidth(width)
	local cols = math.floor((width + CARD_GAP) / (CARD_W + CARD_GAP))
	if cols < 1 then
		cols = 1
	elseif cols > 4 then
		cols = 4
	end
	local buckets = {
		world = {},
		dungeon = {},
		raid = {},
		other = {},
	}
	local cards = CollectCards()
	for i = 1, #cards do
		local card = cards[i]
		if CardMatchesQuery(card, query) then
			local count = #ZoneItems(card.zone, "", false)
			local show = (not filtering or count > 0 or card.here) and true or false
			if show then
				local group = GroupOf(card)
				local list = buckets[group]
				list[#list + 1] = { card = card, count = count }
			end
		end
	end
	local y = 4
	local placed = 0
	for g = 1, #GROUP_ORDER do
		local group = GROUP_ORDER[g]
		local list = buckets[group]
		if #list > 0 then
			table.sort(list, function(a, b)
				return Lower(a.card.name) < Lower(b.card.name)
			end)
			local header = AcquireHeader()
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
			header:SetText(GROUP_LABEL[group])
			y = y + 20
			local col = 0
			for i = 1, #list do
				local entry = list[i]
				local button = AcquireCard()
				button.payload = {
					kind = "place",
					name = entry.card.name,
					here = entry.card.here,
				}
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", content, "TOPLEFT", col * (CARD_W + CARD_GAP), -y)
				PaintCard(button, entry.card, entry.count)
				placed = placed + 1
				col = col + 1
				if col >= cols then
					col = 0
					y = y + CARD_H + CARD_GAP
				end
			end
			if col ~= 0 then
				y = y + CARD_H + CARD_GAP
			end
			y = y + 8
		end
	end
	HideSpareHeaders()
	if placed == 0 then
		y = NoteRow(y, "No zones match.")
	end
	HideSpareRows()
	content:SetHeight(math.max(y + 8, 1))
end

local function RefreshZone()
	HideAllCards()
	HideAllHeaders()
	used = 0
	local width = ContentWidth()
	content:SetWidth(width)
	local query = ns.GetSearchQuery()
	local cards = CollectCards()
	local card = CardForName(cards, selectedName)
	local y = 4
	if card then
		SetWindowTitle(ZoneTitle({ name = card.name, kind = card.kind }))
		y = FillItems(card.zone, card.key, y, query)
	else
		SetWindowTitle("PhatLewt")
		y = NoteRow(y, "Pick a zone from the list.")
	end
	HideSpareRows()
	content:SetHeight(math.max(y + 8, 1))
end

function ns.RefreshList()
	if not window or not content or refreshing then
		return
	end
	refreshing = true
	ApplyChrome()
	if view == "home" then
		RefreshHome()
	else
		RefreshZone()
	end
	refreshing = false
end

local tagCatcher

local function PopupOpen()
	local tagOpen = tagMenu and tagMenu:IsShown()
	local filterOpen = filterMenu and filterMenu:IsShown()
	return tagOpen or filterOpen
end

local function SyncCatcher()
	if not tagCatcher then
		return
	end
	if PopupOpen() then
		tagCatcher:Show()
	else
		tagCatcher:Hide()
	end
end

function HideTagMenu()
	if tagMenu then
		tagMenu:Hide()
	end
	SyncCatcher()
end

local function HideFilterMenu()
	if filterMenu then
		filterMenu:Hide()
	end
	SyncCatcher()
end

local function RefreshFilterChecks()
	if not filterMenu or not filterMenu.checks then
		return
	end
	local filters = PhatLewtDbDB and PhatLewtDbDB.filters or {}
	for i = 1, #filterMenu.checks do
		local check = filterMenu.checks[i]
		check:SetChecked(filters[check.filterID] and true or false)
	end
end

local function ShowFilterMenu()
	if not filterMenu or not filterButton then
		return
	end
	HideTagMenu()
	RefreshFilterChecks()
	filterMenu:ClearAllPoints()
	filterMenu:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -2)
	filterMenu:Show()
	SyncCatcher()
end

function ns.ShowTagMenu(itemID)
	if not tagMenu then
		return
	end
	tagMenu.itemID = itemID
	local current = ns.GetTag(itemID)
	for i = 1, #tagMenu.buttons do
		local button = tagMenu.buttons[i]
		if button.tag == current then
			button:SetNormalFontObject("GameFontNormal")
		else
			button:SetNormalFontObject("GameFontHighlight")
		end
	end
	tagMenu:ClearAllPoints()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	if scale and scale > 0 then
		x = x / scale
		y = y / scale
	end
	tagMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	if filterMenu then
		filterMenu:Hide()
	end
	tagMenu:Show()
	SyncCatcher()
end

local function InitTagMenu()
	tagMenu = CreateFrame("Frame", "PhatLewtDbTagMenu", UIParent, "BackdropTemplate")
	tagMenu:SetFrameStrata("DIALOG")
	tagMenu:SetSize(148, 18 + (#TAG_CHOICES + 1) * 22)
	tagMenu:SetClampedToScreen(true)
	tagMenu:Hide()
	tagMenu:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	tagMenu:SetBackdropColor(1, 1, 1, 1)
	tagMenu:SetBackdropBorderColor(1, 1, 1, 1)
	tagMenu.buttons = {}
	local function AddButton(label, tag, index)
		local button = CreateFrame("Button", nil, tagMenu)
		button:SetSize(132, 20)
		button:SetPoint("TOP", 0, -10 - (index - 1) * 22)
		button:SetNormalFontObject("GameFontHighlight")
		button:SetHighlightFontObject("GameFontNormal")
		button:SetText(label)
		button.tag = tag
		button:SetScript("OnClick", function()
			local itemID = tagMenu.itemID
			if itemID then
				if tag and ns.GetTag(itemID) == tag then
					ns.SetTag(itemID, nil)
				else
					ns.SetTag(itemID, tag)
				end
			end
			HideTagMenu()
		end)
		tagMenu.buttons[#tagMenu.buttons + 1] = button
	end
	for i = 1, #TAG_CHOICES do
		AddButton(TAG_CHOICES[i].label, TAG_CHOICES[i].id, i)
	end
	AddButton("Clear", nil, #TAG_CHOICES + 1)
	tagCatcher = CreateFrame("Button", nil, UIParent)
	tagCatcher:SetAllPoints(UIParent)
	tagCatcher:SetFrameStrata("DIALOG")
	tagCatcher:Hide()
	tagCatcher:SetScript("OnClick", HideTagMenu)
	tagMenu:SetFrameLevel(tagCatcher:GetFrameLevel() + 4)
end

function ns.ShowWindow()
	if not window then
		ns.InitWindow()
	end
	if not window then
		return
	end
	window:Show()
	ShowCurrentZone()
	ns.RefreshList()
	if scroll then
		scroll:SetVerticalScroll(0)
	end
end

function ns.HideWindow()
	HideTagMenu()
	if window then
		window:Hide()
	end
end

function ns.ToggleWindow()
	if window and window:IsShown() then
		ns.HideWindow()
	else
		ns.ShowWindow()
	end
end

function ns.InitWindow()
	if window then
		return
	end
	ns.InitDB()
	InitTagMenu()

	window = CreateFrame("Frame", "PhatLewtDbFrame", UIParent, "ButtonFrameTemplate")
	window:SetFrameStrata("MEDIUM")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetSize(560, 720)
	window:SetScale(ns.FRAME_SCALE)
	window:Hide()
	if window.SetTitle then
		window:SetTitle("PhatLewt")
	elseif window.TitleContainer and window.TitleContainer.TitleText then
		window.TitleContainer.TitleText:SetText("PhatLewt")
	end
	if window.SetPortraitToAsset then
		window:SetPortraitToAsset("Interface\\Icons\\INV_Box_01")
	end
	if ButtonFrameTemplate_HideButtonBar then
		ButtonFrameTemplate_HideButtonBar(window)
	end
	if window.CloseButton then
		window.CloseButton:SetScript("OnClick", function()
			ns.HideWindow()
		end)
	end
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	window:SetScript("OnHide", function()
		SavePosition()
		HideTagMenu()
		HideFilterMenu()
	end)
	if window.TitleContainer then
		window.TitleContainer:EnableMouse(true)
		window.TitleContainer:RegisterForDrag("LeftButton")
		window.TitleContainer:SetScript("OnDragStart", function()
			window:StartMoving()
		end)
		window.TitleContainer:SetScript("OnDragStop", function()
			window:StopMovingOrSizing()
			SavePosition()
		end)
	end
	tinsert(UISpecialFrames, "PhatLewtDbFrame")

	host = window.Inset or window
	searchBox = CreateFrame("EditBox", "PhatLewtDbSearchBox", host, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -PAD)
	searchBox:SetPoint("TOPRIGHT", host, "TOPRIGHT", -(PAD + 108), -PAD)

	viewButton = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
	viewButton:SetSize(70, 22)
	viewButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -(PAD + 32), -(PAD - 1))
	viewButton:SetText("Zones")
	viewButton:SetScript("OnClick", function()
		PlayClick()
		if view == "home" then
			ShowCurrentZone()
		else
			ShowHome()
		end
		ns.RefreshList()
		if scroll then
			scroll:SetVerticalScroll(0)
		end
	end)
	viewButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if view == "home" then
			GameTooltip:SetText("Here")
			GameTooltip:AddLine("Open the zone you are in", 1, 1, 1)
		else
			GameTooltip:SetText("Zones")
			GameTooltip:AddLine("All zones and dungeons", 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	viewButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	filterButton = CreateFrame("Button", nil, host)
	filterButton:SetSize(26, 26)
	filterButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -PAD, -(PAD - 3))
	local filterSlot = filterButton:CreateTexture(nil, "BACKGROUND")
	filterSlot:SetAllPoints()
	if filterSlot.SetAtlas then
		filterSlot:SetAtlas("bags-item-slot64")
	end
	local filterIcon = filterButton:CreateTexture(nil, "ARTWORK")
	filterIcon:SetSize(20, 20)
	filterIcon:SetPoint("CENTER")
	filterIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
	filterIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	filterButton.icon = filterIcon
	filterButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local filterHighlight = filterButton:GetHighlightTexture()
	if filterHighlight then
		filterHighlight:SetAllPoints()
	end
	filterButton:SetScript("OnClick", function()
		if filterMenu and filterMenu:IsShown() then
			HideFilterMenu()
		else
			ShowFilterMenu()
		end
	end)
	filterButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Filters")
		local any = false
		local filters = PhatLewtDbDB and PhatLewtDbDB.filters or {}
		for i = 1, #FILTERS do
			if filters[FILTERS[i].id] then
				any = true
				local r, g, b = 1, 0.82, 0
				if FILTERS[i].quality then
					r, g, b = ns.QualityColor(FILTERS[i].quality)
				end
				GameTooltip:AddLine(FILTERS[i].label, r, g, b)
			end
		end
		if not any then
			GameTooltip:AddLine("Showing every drop", 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	filterButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local filterRowH = 26
	filterMenu = CreateFrame("Frame", "PhatLewtDbFilterMenu", UIParent, "BackdropTemplate")
	filterMenu:SetFrameStrata("DIALOG")
	filterMenu:SetSize(196, 16 + #FILTERS * filterRowH)
	filterMenu:SetClampedToScreen(true)
	filterMenu:Hide()
	filterMenu:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	filterMenu:SetBackdropColor(1, 1, 1, 1)
	filterMenu:SetBackdropBorderColor(1, 1, 1, 1)
	filterMenu.checks = {}
	for i = 1, #FILTERS do
		local spec = FILTERS[i]
		local check = CreateFrame("CheckButton", nil, filterMenu, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("TOPLEFT", 8, -8 - (i - 1) * filterRowH)
		local builtIn = check.Text or check.text
		if builtIn then
			builtIn:SetText("")
			builtIn:Hide()
		end
		local icon = check:CreateTexture(nil, "ARTWORK")
		icon:SetSize(18, 18)
		icon:SetPoint("LEFT", check, "RIGHT", 0, 0)
		icon:SetTexture(spec.icon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		label:SetText(spec.label)
		if spec.quality then
			label:SetTextColor(ns.QualityColor(spec.quality))
		end
		local labelWidth = label:GetStringWidth() or 0
		if labelWidth < 8 then
			labelWidth = #spec.label * 6
		end
		check:SetHitRectInsets(0, -(18 + 6 + labelWidth), 0, 0)
		check.filterID = spec.id
		check:SetScript("OnClick", function(self)
			local on = self:GetChecked() and true or false
			if on then
				PhatLewtDbDB.filters[self.filterID] = true
			else
				PhatLewtDbDB.filters[self.filterID] = nil
			end
			if GameTooltip.GetOwner and GameTooltip:GetOwner() == filterButton then
				filterButton:GetScript("OnEnter")(filterButton)
			end
			ns.RefreshList()
		end)
		filterMenu.checks[#filterMenu.checks + 1] = check
	end
	if tagCatcher then
		filterMenu:SetFrameLevel(tagCatcher:GetFrameLevel() + 4)
	end
	local columnY = -(PAD + 26)

	columnHeader = CreateFrame("Frame", nil, host)
	columnHeader:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, columnY)
	columnHeader:SetPoint("TOPRIGHT", host, "TOPRIGHT", -(PAD + 16), columnY)
	columnHeader:SetHeight(16)
	local headerCursor = -COLUMN_RIGHT
	for i = 1, #COLUMNS do
		local spec = COLUMNS[i]
		local text = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		text:SetJustifyH("RIGHT")
		text:SetWordWrap(false)
		text:SetWidth(spec.width)
		text:SetPoint("RIGHT", headerCursor, 0)
		text:SetText(spec.label)
		headerCursor = headerCursor - spec.width - COLUMN_GAP
	end
	searchBox:SetAutoFocus(false)
	searchBox:SetMaxLetters(40)
	searchBox:SetScript("OnTextChanged", function(self)
		if SearchBoxTemplate_OnTextChanged then
			SearchBoxTemplate_OnTextChanged(self)
		end
		ns.RefreshList()
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self:SetText("")
	end)

	scroll = CreateFrame("ScrollFrame", "PhatLewtDbScroll", host, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, columnY - 18)
	scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -22, PAD)
	local contentLevel = 20
	if host.NineSlice and host.NineSlice.GetFrameLevel then
		contentLevel = host.NineSlice:GetFrameLevel() + 2
	end
	searchBox:SetFrameLevel(contentLevel)
	filterButton:SetFrameLevel(contentLevel)
	viewButton:SetFrameLevel(contentLevel)
	columnHeader:SetFrameLevel(contentLevel)
	scroll:SetFrameLevel(contentLevel)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(360, 1)
	scroll:SetScrollChild(content)

	window:SetScript("OnMouseDown", function()
		HideTagMenu()
		HideFilterMenu()
	end)

	RestorePosition()
end

local function AnchorLooseButton()
	if not minimapButton or docked or not Minimap then
		return
	end
	minimapButton:SetParent(UIParent)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "LEFT", 0, 0)
	minimapButton:Show()
end

function ns.DockMinimapButton()
	if not minimapButton then
		return
	end
	if type(TobarisuMap) == "table" and type(TobarisuMap.RegisterWidget) == "function" then
		TobarisuMap.RegisterWidget("PhatLewtDb", {
			frame = minimapButton,
			edge = "W",
			size = 26,
		})
		docked = true
		minimapButton:Show()
		return
	end
	docked = false
	AnchorLooseButton()
end

local function InitMinimapButton()
	if minimapButton then
		ns.DockMinimapButton()
		return
	end
	minimapButton = CreateFrame("Button", "PhatLewtDbMinimapButton", UIParent)
	minimapButton:SetSize(26, 26)
	minimapButton:RegisterForClicks("LeftButtonUp")
	minimapButton:SetFrameStrata("MEDIUM")

	local disc = minimapButton:CreateTexture(nil, "BACKGROUND")
	disc:SetAllPoints()
	disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	disc:SetVertexColor(0.08, 0.06, 0.04, 1)

	-- The ring art sits in the top-left of the texture. Shift it so the
	-- circle lands on the button, matching the bug-report button (60px, +11, -12).
	local ring = minimapButton:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(42, 42)
	ring:SetPoint("CENTER", 8, -8)

	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local highlight = minimapButton:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
		highlight:ClearAllPoints()
		highlight:SetPoint("CENTER")
		highlight:SetSize(22, 22)
	end

	local label = CreateFrame("Frame", nil, minimapButton)
	label:SetAllPoints()
	label:SetFrameLevel(minimapButton:GetFrameLevel() + 2)
	local text = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if not text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") then
		text:SetFontObject("GameFontNormalSmall")
	end
	text:SetText("PLDB")
	text:SetTextColor(1, 0.82, 0)
	text:SetPoint("CENTER", 0, 0)

	minimapButton:SetScript("OnClick", function()
		ns.ToggleWindow()
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("PhatLewtDb")
		GameTooltip:AddLine("Open the loot log", 1, 1, 1)
		GameTooltip:AddLine("Drag around the map", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	ns.DockMinimapButton()
end

function ns.InitUI()
	ns.InitWindow()
	InitMinimapButton()
end
