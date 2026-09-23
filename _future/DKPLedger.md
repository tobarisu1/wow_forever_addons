# DKPLedger (pending)

Personal raid DKP ledger for Forever. Not built yet. Iterate in-game; this doc is the starting contract.

Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline 12.1.5 (`## Interface: 120105`). No Ace3. Slash commands, not an options panel. Match GatherMemory: one account SavedVariables file, copy via `./scripts/link-addon.sh`, never symlink.

## Goal

Open a raid with a slash command. When a boss dies, credit **1 DKP** to people who were in the raid. When the **final boss** dies, credit **5 DKP** instead of 1. Persist that ledger locally. Later, a companion process (Mini Mac or AWS) uploads it for a guild site.

The addon is an **offline producer**. It cannot HTTP, open sockets, or write an arbitrary path. Remote storage is a separate service watching the SavedVariables file.

## First version

- `/dkp start <raid>` — begin a raid night (`mc`, `ony`, `bwl`, and so on)
- Snapshot **roster** at each award (`GetNumGroupMembers` + `GetRaidRosterInfo` / `raid1`…`raidN`), not Compact Raid Frame widgets
- Award on `ENCOUNTER_END` with `success == 1`; skip wipes (`success == 0`)
- Last-boss map is a small static table (raid key → final encounter), not a community loot DB
- Always keep `/dkp kill` and `/dkp final` so a missing event does not block the night
- Store nested tables plus one JSON string field for ETL
- `/dkp status`, `/dkp stop`, `/dkp` with no args prints the menu
- Each credit is its own **award row** (see below), not a running total that drops the kill details

Suggested aliases: `/dkp` and `/dkpledger`. TOC global `DkpLedgerDB`. `## LoadSavedVariablesFirst: 1`.

## Award row

One row per player per successful boss kill. Totals are derived later (sum `dkp` for a character). The JSON packed field uses the same keys.

| Field | Meaning | Source |
|---|---|---|
| `characterName` | Name as on the roster | `GetRaidRosterInfo` / `UnitNameUnmodified`, scrub secrets |
| `class` | Localized class name (`Warrior`) | `GetRaidRosterInfo` class / `UnitClass` |
| `classFile` | Token (`WARRIOR`) | `UnitClass` fileName — stable for ETL |
| `spec` | Spec name if the client has one | See spec note below |
| `bossName` | Encounter display name | `ENCOUNTER_END` `encounterName`, or the name passed to `/dkp kill` |
| `encounterID` | Numeric encounter if known | `ENCOUNTER_END`; `nil` on a fully manual award |
| `dkp` | Points for this kill | `1` normal, `5` final boss |
| `killedAt` | Unix time of the kill | `GetServerTime()` when the award is written |

Example:

```lua
{
	characterName = "Toad",
	class = "Warrior",
	classFile = "WARRIOR",
	spec = "Protection", -- or nil
	bossName = "Ragnaros",
	encounterID = 672, -- whatever Forever actually sends; do not hardcode until traced
	dkp = 5,
	killedAt = 1726900000,
}
```

Do not collapse these into a per-player counter in SavedVariables. Keep the list of rows so the guild site can filter by boss, class, spec, and night.

**Spec:** Forever is vanilla-era. Retail-style specs may be missing or empty. `C_SpecializationInfo.GetSpecialization` is reliable for **you**; other raid members need inspect (`isInspect`), which is throttled and a poor fit in combat at kill time. v1 stores `spec` when a cheap API returns it, otherwise `nil`. Do not inspect-spam 40 units on `ENCOUNTER_END`. Revisit if Forever exposes spec on the roster.

**Timestamp:** `GetServerTime()` is UTC seconds, good for ETL. A human string can be formatted at export; do not store only `date()` local time as the canonical value.

## Presence

Credit who is in the **raid roster at award time**, not who was there at `/dkp start`. People who join mid-raid get the later kills.

Do not scrape `CompactRaidFrame` name fonts. `UnitName` can be a secret value; scrub with the GatherMemory `issecretvalue` / `tonumber` pattern.

Decide later, with explicit commands if needed:

- Offline / disconnected
- Not in the instance
- Bench sitting in group 8

## Boss detection

`COMBAT_LOG_EVENT_UNFILTERED` does not fire for addons on 12.x. Do not listen for `UNIT_DIED`.

Use Mainline encounter events (local UI source: `EncounterInfoDocumentation.lua`):

- `ENCOUNTER_START` / `ENCOUNTER_END` — payload includes `encounterID`, name, `groupSize`, and `success` (0/1)
- `BOSS_KILL` — `encounterID`, `encounterName`

Prefer **`ENCOUNTER_END` only**. Listening to both will double-credit.

**Forever risk:** vanilla raid scripts may not fire these events. Before relying on automation, `/eventtrace` on a real kill. If nothing fires, fall back to:

- `UPDATE_INSTANCE_INFO` + `GetInstanceLockTimeRemainingEncounter`
- `C_RaidLocks.IsEncounterComplete` (needs real encounter IDs)
- Manual `/dkp kill` / `/dkp final`

## Persistence

WoW serializes TOC globals on logout, `/reload`, or quit:

`WTF/Account/<account>/SavedVariables/DKPLedger.lua`

There is no flush API mid-session. A kill lives in memory until the next write. Post-raid `/reload` or logout is the normal load. Near-live guild display means reload after a boss, or accept batch-after-raid.

Keep `DkpLedgerDB` as plain tables (string / number / bool / table only). Also keep `DkpLedgerDB.packed` as a JSON string: schema version, raid id, and the **award row list** (`characterName`, `class`, `classFile`, `spec`, `bossName`, `encounterID`, `dkp`, `killedAt`). The watcher should not have to parse Lua.

`CopyToClipboard` exists for a manual dump. `C_ChatInfo.SendAddonMessage` only talks to other clients in raid/guild; it never leaves the game.

## Companion (not this addon)

```
DKPLedger.lua  →  file watcher (launchd on Mini Mac)
               →  parse JSON field
               →  put object (S3 / R2 / Postgres / HTTP API)
               →  guild app reads with IAM / signed URLs
```

Debounce: WoW rewrites the whole file. Upsert by `(raid_id, encounter_id, characterName, killedAt)` so `/reload` is idempotent and two bosses in one night stay distinct.

Security lives in the remote store, not the addon. The `.lua` file is plaintext on disk. No cloud keys in Lua. One officer machine is the writer until there is a merge rule.

Two officers running the addon means two files. Pick a source of truth.

## Out of scope for v1

- Guild-wide live DKP inside the game
- Loot bid / item-value DKP
- Ace, settings panels, imported raid databases
- Writing CSV to the Desktop from Lua

## Verify later

1. `/eventtrace` during a Forever raid boss kill
2. Roster names survive secret-value checks
3. Each award row has name, class, bossName, dkp, and `killedAt`; spec may be nil
4. SavedVariables round-trip after `/reload` (copy script, never symlink)
5. JSON field is valid after a full raid night
