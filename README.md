# wow_forever_addons

Personal addons for [World of Warcraft: Forever](https://github.com/tobarisu1/wow_forever_addons). Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline: write addons against the **12.1.5 API set**, not Classic Era / 1.12. Lua is still 5.1 plus a `.toc` with `## Interface: 120105`.

## Design philosophy

These addons stay small. They add quality of life, not a second game on top of the game. You operate them with slash commands (`/gm`, `/bm`, `/mtt`, and so on) instead of options panels. Type the command with no arguments to print a short menu; `on` / `off` / `status` is the usual shape.

The other rule is **earned knowledge**. The addons compound on what you yourself find in the world. They do not import a shared database from the rest of the playerbase. If you gather more herb and ore nodes, GatherMemory then makes it easier to find those same resources again. The map is yours because you walked it.

Pending addons live as design docs under `_future/` until they have a `.toc`. **[PhatLewtDb](_future/PhatLewtDb.md)** is the loot log (your drops, not a community table). **[DKPLedger](_future/DKPLedger.md)** is a personal raid DKP ledger plus a later companion upload.

## Layout

```
Angler/                  double-right-click fishing, lure menu, background sound; /an
BagMaster/               stalled; combined bags; researching Baganator; /bm
CursorTooltip/           mouse-cursor tooltips; /mtt on | off | status
GatherMemory/            personal herb/ore/chest/fish tracker; /gm for options
OldManQuester/           quest UI for ultrawide (and easier reading); /omq
SplitChat/               stalled; chat left, logs right; researching Baganator; /sc
TobarisuMap/             square movable minimap; /tmap for options
_future/                 design docs for addons not built yet
  DKPLedger.md           raid DKP ledger; per-kill rows (name, class, spec, boss, time)
  PhatLewtDb.md          personal loot log; drops, sources, drop rates
scripts/link-addon.sh    Mac: copy addons into the Forever client
scripts/link-addon.bat   Windows: copy addons into the Forever client
```

Add a new addon by creating `YourAddon/YourAddon.toc` at the repo root and listing its `.lua` files there.

## Install on Mac

Default WoW root is `/Applications/World of Warcraft`. Forever beta lives in `_classic_beta_`.

```bash
./scripts/link-addon.sh
```

That creates `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns` if needed and copies each addon folder at the repo root (`FolderName/FolderName.toc`) into it. **BagMaster** and **SplitChat** are skipped by default (and removed from AddOns if a previous copy is there) so Banganator and Chatanator can be used instead. Pass `--all` to include them. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

The client gets its own copy, so **re-run the script after editing** and fully restart WoW when the change is a new file or TOC. Lua-only edits need `/reload`. SavedVariables persist across `/reload` and relog.

Optional overrides:

```bash
./scripts/link-addon.sh --all
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

You can also double-click `scripts\link-addon.bat`. That creates `_classic_beta_\Interface\AddOns` if needed and copies each addon folder (`FolderName\FolderName.toc`) into it with `robocopy /MIR`. **BagMaster** and **SplitChat** are skipped by default; pass `--all` to include them. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

As on Mac, the client gets its own copy, so re-run it after editing and fully restart WoW.

If the client is not in the default location:

```bat
set WOW_ROOT=D:\Games\World of Warcraft
scripts\link-addon.bat
```

Or pass a client folder / AddOns path:

```bat
scripts\link-addon.bat --all
scripts\link-addon.bat _classic_beta_
scripts\link-addon.bat "D:\Games\World of Warcraft\_classic_beta_"
scripts\link-addon.bat "D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns"
```

If linking fails, run Command Prompt as Administrator, or turn on **Settings > System > For developers > Developer Mode**.

Then, at the character-select screen, click **AddOns**, enable **Angler**, **CursorTooltip**, **GatherMemory**, **OldManQuester**, and **TobarisuMap**, and log in. Enable **BagMaster** and **SplitChat** only if you copied with `--all`.

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

## BagMaster

**Currently stalled.** Work is paused while I research how Baganator features function, so a sleeker bag UI can replace this design. The copy script skips this addon by default.

Replaces the default bag window with a dark, borderless panel. Default layout groups items into labeled category sections (Quest, Consumable, Weapon, Armor, Crafting types, Junk, Empty). `/bm bags` restores per-bag sections. Quest items get a gold highlight. The search box dims non-matches; type `quest`, `junk`, `empty`, and similar keywords to also match by type.

- `/bm` — print the menu and current state
- `/bm on` — enable
- `/bm off` — disable
- `/bm bags` — per-bag sections
- `/bm categories` — category sections
- `/bm items on | off` — bag quest-item highlight
- `/bm search` — open bags and focus the search box
- `/bm status` — print ON or OFF, layout, and items

`/bagmaster` is an alias. On/off, layout, items, and window position are saved across `/reload` and logins. Drag the window to move it. Press B or the bag key to open it.

## CursorTooltip

Anchors the default GameTooltip (world units and objects) to the mouse cursor.

- `/mtt` — print the menu and current state
- `/mtt on` — enable
- `/mtt off` — disable
- `/mtt status` — print ON or OFF

`/cursortooltip` is an alias. The last on/off choice is saved across `/reload` and logins.

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

## SplitChat

**Currently stalled.** Same pause as BagMaster: researching how Baganator-class UI features work before implementing a sleeker design. The copy script skips this addon by default.

Two movable chat panes sized for ultrawide. Communication stays on the left (General, Guild, Group, Whisper). Combat log, loot, world (XP, skills, achievements), and system sit on the right. The default Blizzard chat dock and frame art are hidden while SplitChat is on. Message groups are a fixed account-wide layout covering every Blizzard chat type (including guild discord, voice text, and pet battles when the client has them). Uses Blizzard chat frames, so name-click whisper, item/spell links, and the rest of the default chat mouse behavior stay intact. Class-colored names are turned on. Default typeface is Arial Narrow; default size is 20.

- `/sc` — print the menu and current state
- `/sc on` — enable
- `/sc off` — disable
- `/sc lock` — stop dragging
- `/sc unlock` — drag **Move** or resize from the corner
- `/sc font` — list faces and sizes
- `/sc font arial | friz | morpheus | skurri | 2002`
- `/sc font 12 | 14 | 16 | 18 | 20 | 24 | 27`
- `/sc reset` — rebuild the default tabs
- `/sc status`

`/splitchat` is an alias. Pane positions, lock, face, size, and tab layout are saved account-wide. `/sc reset` reapplies the message groups.

## TobarisuMap

Restyles the Blizzard minimap into a square, borderless, movable map with mousewheel zoom and a clean zone-name header. After you zoom with the wheel, it steps back to your home zoom after a short idle. Future addons can dock onto the eight border edges through `TobarisuMap.RegisterWidget`.

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

TOCs use Mainline `120105` (patch 12.1.5). If the addon list marks an addon out of date, log in and run:

```
/run print(select(4, GetBuildInfo()))
```

Put that number in `## Interface:`.
