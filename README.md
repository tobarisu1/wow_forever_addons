# wow_forever_addons

Personal addons for [World of Warcraft: Forever](https://github.com/tobarisu1/wow_forever_addons). Forever gameplay is vanilla-era (level cap 60). The client is Forever **1.60.1**. Write addons against Mainline APIs, not Classic Era / 1.12. Lua is still 5.1 plus a `.toc` with `## Interface: 16001`. That number comes from the live client, not from the retail patch the UI source was built on.

## Design philosophy

These addons stay small. They add quality of life, not a second game on top of the game. You operate them with slash commands (`/gm`, `/bm`, `/mtt`, and so on) instead of options panels. Type the command with no arguments to print a short menu; `on` / `off` / `status` is the usual shape.

The other rule is **earned knowledge**. The addons compound on what you yourself find in the world. They do not import a shared database from the rest of the playerbase. If you gather more herb and ore nodes, GatherMemory then makes it easier to find those same resources again. The map is yours because you walked it.

Shared processing lives in **BackendMaster**. It keeps this character's bags, bank, and money, and it describes an item (junk, reagent, and the other kinds) plus which of your recipes use it. Addons that need that picture call BackendMaster instead of scanning containers or professions themselves. BagMaster reads the bag cache. TooltipMaster reads the item facts.

Pending addons live as design docs under `_future/` until they have a `.toc`. **[DKPLedger](_future/DKPLedger.md)** is a personal raid DKP ledger plus a later companion upload. PhatLewtDb is the loot log (your drops, not a community table).

## Layout

```
Angler/                  double-right-click fishing, lure menu, background sound; /an
BackendMaster/           shared bag and bank cache for other addons; /be
BagMaster/               category bag window; reads BackendMaster; /bm
CombatTextMaster/        ready alerts and incoming damage for rogue, warrior, priest, shaman; /ctm
CursorTooltip/           mouse-cursor tooltips; /mtt on | off | status
TooltipMaster/           item tooltip lines for kind and profession use; /tm
GatherMemory/            personal herb/ore/chest/fish tracker; /gm for options
OldManQuester/           quest UI for ultrawide (and easier reading); /omq
PhatLewtDb/              personal loot log; zone, mob, and drop rates; /pld
TobarisuMap/             square movable minimap; /tmap for options
_future/                 design docs for addons not built yet
  DKPLedger.md           raid DKP ledger; per-kill rows (name, class, spec, boss, time)
  SplitChat/             parked chat panes; use Chatanator until this is redesigned
scripts/link-addon.sh    Mac: copy addons into the Forever client
scripts/link-addon.bat   Windows: copy addons into the Forever client
```

Add a new addon by creating `YourAddon/YourAddon.toc` at the repo root and listing its `.lua` files there.

## Install on Mac

Default WoW root is `/Applications/World of Warcraft`. Forever beta lives in `_classic_beta_`.

```bash
./scripts/link-addon.sh
```

That creates `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns` if needed and copies each addon folder at the repo root (`FolderName/FolderName.toc`) into it, including **BackendMaster** and **BagMaster**. **SplitChat** is parked and removed from AddOns if a previous copy is there. BagMaster needs BackendMaster enabled. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

The client gets its own copy, so **re-run the script after editing** and fully restart WoW when the change is a new file or TOC. Lua-only edits need `/reload`. SavedVariables persist across `/reload` and relog.

Optional overrides:

```bash
./scripts/link-addon.sh _classic_beta_
./scripts/link-addon.sh "/Applications/World of Warcraft/_classic_beta_/Interface/AddOns"
```

Enable each addon on the character-select screen.

## Install on Windows

Default WoW root is `C:\Program Files (x86)\World of Warcraft`, then `C:\Program Files\World of Warcraft`. Forever beta lives in `_classic_beta_`.

From Command Prompt or PowerShell, in this repo:

```bat
scripts\link-addon.bat
```

You can also double-click `scripts\link-addon.bat`. That creates `_classic_beta_\Interface\AddOns` if needed and copies each addon folder (`FolderName\FolderName.toc`) into it with `robocopy /MIR`, including **BackendMaster** and **BagMaster**. **SplitChat** is parked and removed from AddOns if a previous copy is there. BagMaster needs BackendMaster enabled. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

As on Mac, the client gets its own copy, so re-run it after editing and fully restart WoW.

If the client is not in the default location:

```bat
set WOW_ROOT=D:\Games\World of Warcraft
scripts\link-addon.bat
```

Or pass a client folder / AddOns path:

```bat
scripts\link-addon.bat _classic_beta_
scripts\link-addon.bat "D:\Games\World of Warcraft\_classic_beta_"
scripts\link-addon.bat "D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns"
```

If linking fails, run Command Prompt as Administrator, or turn on **Settings > System > For developers > Developer Mode**.

Then, at the character-select screen, click **AddOns**, enable **Angler**, **BackendMaster**, **BagMaster**, **CombatTextMaster**, **CursorTooltip**, **GatherMemory**, **OldManQuester**, **PhatLewtDb**, **TobarisuMap**, and **TooltipMaster**, and log in. Use **Chatanator** for chat. BagMaster, PhatLewtDb, and TooltipMaster will not start unless BackendMaster is enabled.

## Angler

Double-right-click anywhere with a fishing pole equipped to cast Fishing. If the pole has no lure, a cursor menu lists vanilla lures in your bags; click one to apply it, or the pass (X) button to ignore lures for five minutes. While a fishing channel is active, background sound is turned on so you can hear the bobber while alt-tabbed; the previous setting is restored when you stop.

- `/an` — print the menu and current state
- `/an on` — enable
- `/an off` — disable
- `/an click on | off` — double-right-click to fish
- `/an lures on | off` — lure menu
- `/an sound on | off` — background-sound automation
- `/an status` — print ON or OFF and the three feature flags

`/angler` is an alias. On/off and the three feature flags are saved across `/reload` and logins.

## BackendMaster

Shared bag and bank cache, plus item facts for other addons. It scans the bags and bank you are carrying, stores that picture per character in `BackendMasterDB`, and exposes it on the `BackendMaster` table. Other addons read that table. They do not scan containers or open `BackendMasterDB` themselves. BagMaster reads the cache. TooltipMaster calls `BackendMaster.DescribeItem` and `BackendMaster.GetItemUses`. The recipe index stays in memory: it is filled from professions the client already knows, and again when you open a profession. It is not saved and it is not a shipped recipe list.

- `/be` — print the menu and current cache
- `/be status` — character, whether a scan is in progress, bag and bank item counts, and money

`/backendmaster` is an alias. The cache is saved across `/reload` and logins.

## BagMaster

Working. Replaces the default bag window with a gold-bordered parchment panel sized to the items inside it. Item lists come from BackendMaster. The default layout groups items into labeled sections (Quest, Consumable, Weapon, Armor, Crafting types, Junk, Empty). The **Type** button in the window switches that to one section per worn bag, and back. Gold sits at the bottom right, with currencies on that same row. Empty slots inside a worn bag still show; bag slots you have not equipped do not. Quest items get a gold highlight. The search box dims non-matches; type `quest`, `junk`, `empty`, and similar keywords to also match by type.

Enable **BackendMaster** as well, or BagMaster stays off.

- `/bm` — print the menu and current state
- `/bm on` — enable
- `/bm off` — disable
- `/bm bags` — per-bag sections
- `/bm categories` — category sections
- `/bm items on | off` — bag quest-item highlight
- `/bm search` — open bags and focus the search box
- `/bm status` — print ON or OFF, layout, and items

`/bagmaster` is an alias. On/off, layout, items, and window position are saved across `/reload` and logins. Drag the window to move it. Press B or the bag key to open it.

## CombatTextMaster

Shows gold ready text above your character, and the damage you take. The damage you deal stays as the game's numbers over your target. For now the list is rogue, warrior, priest, and shaman.

`/ctm` opens a portrait window. **Look** picks the font, size, and outline, with a sample of the alert and a damage number. **Alerts** is the list for this character: a class header, then each learned ability. Open a row for what it watches. Uncheck a row to silence it. Abilities this character has not learned stay off the list.

Two kinds of alert:

- **Ready.** The game announces these when they become usable: Riposte, Overpower, and Revenge.
- **Short cooldown.** This addon watches the cooldown and uses the same gold text when it is ready again.

| Class | Ready | Short cooldown |
|---|---|---|
| Rogue | Riposte | Kick, Ghostly Strike, Kidney Shot |
| Warrior | Overpower, Revenge | Mortal Strike, Bloodthirst, Shield Slam, Whirlwind |
| Priest | | Mind Blast, Holy Fire, Power Word: Shield |
| Shaman | | Stormstrike, Earth Shock |

Earth Shock stands in for the shared shock cooldown, so Flame Shock and Frost Shock come off cooldown with it.

- `/ctm` — print the menu and open Look
- `/ctm alerts` — open the alert list
- `/ctm on` — enable
- `/ctm off` — disable
- `/ctm status` — print ON or OFF, font, size, and outline

`/combattext` is an alias. Drag the title bar to move the window. The font, outline, size, window position, and which alerts are on are saved across `/reload` and logins.

## CursorTooltip

Anchors the default GameTooltip (world units and objects) to the mouse cursor.

- `/mtt` — print the menu and current state
- `/mtt on` — enable
- `/mtt off` — disable
- `/mtt status` — print ON or OFF

`/cursortooltip` is an alias. The last on/off choice is saved across `/reload` and logins.

## TooltipMaster

Adds lines to the default item tooltip. The frame stays the Blizzard tooltip. A gray item is labeled Junk. Other items get one kind line (Quest, Reagent, Trade Goods, Recipe, and the same set BagMaster uses). When BackendMaster has seen a recipe that spends the item, the tooltip lists that profession, recipe, and count, up to eight recipes.

Needs **BackendMaster**. The kind line is there as soon as you hover. Recipe lines show up for professions the client returns at login, and for any profession window you open.

- `/tm` — print the menu and current state
- `/tm on` — enable
- `/tm off` — disable
- `/tm status` — print ON or OFF

`/tooltipmaster` is an alias. The last on/off choice is saved across `/reload` and logins.

## GatherMemory

Remembers herbs, ore, chests, and fishing pools **you** gather and shows those spots on the minimap and world map. No shared spawn database.

- `/gm` — print the menu and current state
- `/gm herbs | ore | chests | fish on | off` — show or hide that kind
- `/gm minimap | worldmap on | off`
- `/gm status`
- `/gm clear zone` — delete nodes in the current zone
- `/gm clear all` — delete every saved node
- `/gm prune` — delete chest records that are not real treasure chests
- `/gm debug` — report what was loaded from the saved variables file
- `/gm where` — report the numbers behind the current minimap pin positions

`/gathermemory` is an alias. Pins use the gathered item's icon (Kingsblood, Battered Chest, Firefin Snapper, and so on). Hover a pin for name, kind, and skill requirement.

Nodes are stored account wide in `GatherMemoryDB`, so every character shares the same map. Records are only ever removed by `/gm clear` or `/gm prune`; nothing else deletes them. A record the current version cannot read is kept as-is rather than discarded, so it is never lost to a format change.

## OldManQuester

Primarily for ultrawide (and if you are old and want to see easier). Keeps the default left-docked quest and gossip windows, but scales them up so they use more of the extra width and are easier to read. The character window is the old 384×512 sheet (portrait, side slots, model, stat boxes, resistances, bottom tabs) at that same scale. Scales the windowed map/quest log (L) to match; the fullscreen map stays normal size. Keeps the quest tracker compact, fully transparent, and faded until you mouse over it.

- `/omq` — print the menu and current state
- `/omq on` — enable
- `/omq off` — disable
- `/omq tracker on | off` — compact transparent tracker
- `/omq status` — print dialog and tracker state

`/oldmanquester` is an alias. The last on/off choices are saved across `/reload` and logins.

## PhatLewtDb

Personal loot log. The window opens on the zone you are in and lists items first. Click an item to see which monsters there drop it, best rate first. Rate, times seen, stack, and tag stay in columns. Dungeons and raids use the instance name. Epic, rare, and uncommon drops are listed first. The spyglass beside the search box opens a filter menu. Check crafting, greens, rares, and the other rows to limit the list. Leave them all off to show everything. Right-click an item to tag it quest, crafting, equipment, or junk. Hover an item for its tooltip.

Needs **BackendMaster**. A round **PLDB** button sits on the left edge of the minimap. Drag it to any side of the square.

- `/pld` — print the menu and open the window
- `/pld status` — print how many zones, mobs, and items are saved
- `/pld clear zone` — delete drops for the current zone
- `/pld clear all` — delete every drop

`/phatlewt` is an alias. Loot is saved whenever you open a corpse, chest, or container. The log, tags, and window position are saved account-wide across `/reload` and logins. Drops are only removed by `/pld clear`.

## TobarisuMap

Restyles the Blizzard minimap into a square, borderless, movable map with mousewheel zoom and a clean zone-name header. After you zoom with the wheel, it steps back to your home zoom after a short idle. Other addons dock a button on the square through `TobarisuMap.RegisterWidget`. Drag a button and it follows the nearest side of the square. That spot is saved.

- `/tmap` — print the menu and current state
- `/tmap on` — show the map
- `/tmap off` — hide the map
- `/tmap status`
- `/tmap lock` — stop dragging
- `/tmap unlock` — drag the map to move it
- `/tmap zoom <0-5>` — set the home zoom (0 is zoomed out)

`/tobarisumap` is an alias. Position, lock, visibility, and home zoom are saved across `/reload` and logins. If GatherMemory is also loaded, its minimap pins use the square edges and larger icons, and the map shows a tracking pulse.

## Reload vs restart

- Lua-only edits: `/reload` in game
- TOC or new-file changes: `/reload` usually works; restart the client if it does not show up

## Interface version

TOCs use `16001` (Forever 1.60.1). That number is the live client's interface, from `select(4, GetBuildInfo())`. If the addon list marks an addon out of date, log in and run:

```
/run print(select(4, GetBuildInfo()))
```

Put that number in `## Interface:`.
