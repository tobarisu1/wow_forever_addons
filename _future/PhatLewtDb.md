# PhatLewtDb (pending)

Personal loot log for Forever. Not built yet. Same idea as GatherMemory: **your** drops, not a community table.

Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline 12.1.5 (`## Interface: 120105`). No Ace3. Slash commands, not an options panel. Copy via `./scripts/link-addon.sh`. Never symlink, or SavedVariables reset every login.

## Goal

Record item drops, the mob or object they came from, where you were, and simple drop rates from **this character’s** (or this account’s) kills. Search that log from a short slash menu.

Do not import Wowhead, AtlasLoot, or any shared loot table. If you never looted it, it is not in the DB.

## First version

- On loot window open, record each item slot: item id / name / quantity, source name if known, map id, x/y, time
- Account-wide SavedVariables (share the log across alts), same as GatherMemory
- `/pld search <text>` — print matching items and where they dropped
- `/pld status` — counts
- `/pld` with no args prints the menu
- `/pld on | off` — pause recording without wiping data

Suggested aliases: `/pld` and `/phatlewt`. TOC global `PhatLewtDb`. `## LoadSavedVariablesFirst: 1`.

Keep records as tables plus an optional packed string if a later companion wants to ingest them. Do not build HTTP into the addon (see DKPLedger: the client cannot push to remote storage).

## How to record loot (12.x)

`COMBAT_LOG_EVENT_UNFILTERED` does not fire for addons. You cannot key off `UNIT_DIED` and then guess loot.

Use loot UI events (local UI source: `LootDocumentation.lua`):

- `LOOT_READY` / `LOOT_OPENED` — window is up; `autoLoot` / `isFromItem` on open
- Slot APIs as used by Blizzard loot frames (`GetNumLootItems`, slot type, item link, quantity)
- `LOOT_CLOSED` — end of that open
- `ENCOUNTER_LOOT_RECEIVED` — may fire for encounter loot; verify on Forever before depending on it

Source and location:

- Unit token for the corpse if still available (`target`, mouseover, or loot source APIs — look up in `wow-ui-source` at implementation time; do not invent Classic-only helpers)
- `C_Map.GetBestMapForUnit("player")` and player map position for the pin
- Item identity through `C_Item` / item links, not removed `GetSpellInfo`-style globals

Scrub secret values the GatherMemory way. Item links, names, and unit names can be secret; never compare or concatenate a value before `issecretvalue` / `canaccessvalue` / `tonumber`.

## Drop rates

True “kills vs drops” needs a kill event. Without CLEU, v1 should define rate as **loot opens that contained the item / loot opens on that source name** (or on that NPC id if you can get it). Say so in `/pld` output so it is not mistaken for a community percent.

Skinning, mining, and herb loot on corpses can share a loot window — tag source kind when you can, skip when you cannot.

Money slots (`Enum.LootSlotType.Money`) can be ignored in v1. Currency too, unless Forever uses it for something you care about.

## Search UI

Stay slash-first. Print a short list to chat. A later frame (filter box, scroll) is optional and not required to ship recording.

Useful queries once data exists:

- Item name substring
- Zone / current map
- Source name
- Quality (if readable without tainting)

## Persistence

`WTF/Account/<account>/SavedVariables/PhatLewtDb.lua`

Same rules as GatherMemory: only string / number / bool / table. Init with `== nil` so `enabled = false` survives. A record the current version cannot parse is kept, not dropped.

Dedup: one loot window must not record twice if `LOOT_READY` and `LOOT_OPENED` both fire. Key an open by time + source + slot item ids.

`/pld clear zone` and `/pld clear all` later, matching GatherMemory. Do not auto-delete.

## Out of scope for v1

- Imported loot tables or rare-spawn lists
- Auction prices
- Raid DKP (that is DKPLedger)
- Ace, options panels, map pins (pins can wait until the log is trustworthy)
- Pushing the file to S3 from Lua

## Verify later

1. `/eventtrace` while looting a beast, a humanoid, a chest, and a boss
2. Autoloot vs manual loot both record once
3. Secret-safe item id / name reads
4. SavedVariables round-trip after `/reload`
5. Search finds a drop you just took
