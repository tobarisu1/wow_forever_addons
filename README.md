# wow_forever_addons

Personal addons for [World of Warcraft: Forever](https://github.com/tobarisu1/wow_forever_addons). Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline: write addons against the **12.1.5 API set**, not Classic Era / 1.12. Lua is still 5.1 plus a `.toc` with `## Interface: 120105`.

## Layout

```
BagMaster/               combined bags with per-bag sections; /bm to toggle
CursorTooltip/           mouse-cursor tooltips; /mtt on | off | status
GatherMemory/            personal herb/ore/chest/fish tracker; /gm for options
OldManQuester/           quest UI for ultrawide (and easier reading); /omq
TobarisuMap/             square movable minimap; /tmap for options
scripts/link-addon.sh    Mac: copy addons into the Forever client
scripts/link-addon.bat   Windows: copy addons into the Forever client
```

Add a new addon by creating `YourAddon/YourAddon.toc` at the repo root and listing its `.lua` files there.

## Install on Mac

Default WoW root is `/Applications/World of Warcraft`. Forever beta lives in `_classic_beta_`.

```bash
./scripts/link-addon.sh
```

That creates `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns` if needed and copies each addon folder at the repo root (`FolderName/FolderName.toc`) into it. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

The client gets its own copy, so **re-run the script after editing** and fully restart WoW. Copying rather than symlinking is deliberate: a symlinked addon folder loads its Lua normally, but the client never reads its SavedVariables back, so anything the addon saves silently resets on the next login.

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

You can also double-click `scripts\link-addon.bat`. That creates `_classic_beta_\Interface\AddOns` if needed and copies each addon folder (`FolderName\FolderName.toc`) into it with `robocopy /MIR`. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

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

Then, at the character-select screen, click **AddOns**, enable **BagMaster**, **CursorTooltip**, **GatherMemory**, **OldManQuester**, and **TobarisuMap**, and log in.

## BagMaster

Keeps Blizzard Combined Bags as one window, but stacks each bag as its own labeled 10-column section. Long bag names are clipped to a short uniform label. The window is scaled up (~1.3x) so slots are easier to read.

- `/bm` — print the menu and current state
- `/bm on` — enable
- `/bm off` — disable
- `/bm status` — print ON or OFF

`/bagmaster` is an alias. On/off is saved across `/reload` and logins. When enabled, Combined Bags is turned on; turning BagMaster off restores your previous bag mode.

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

Primarily for ultrawide (and if you are old and want to see easier). Keeps the default left-docked quest and gossip windows, but scales them up so they use more of the extra width and are easier to read. Scales the windowed map/quest log (L) to match; the fullscreen map stays normal size. Keeps the quest tracker compact, fully transparent, and faded until you mouse over it. Also paints a high-contrast gold highlight on quest items in your bags.

- `/omq` — print the menu and current state
- `/omq on` — enable
- `/omq off` — disable
- `/omq items on | off` — bag quest-item highlight
- `/omq tracker on | off` — compact transparent tracker
- `/omq status` — print dialog, items, and tracker state

`/oldmanquester` is an alias. The last on/off choices are saved across `/reload` and logins.

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
