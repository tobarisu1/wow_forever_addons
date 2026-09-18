# wow_forever_addons

Personal addons for [World of Warcraft: Forever](https://github.com/tobarisu1/wow_forever_addons). Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline: write addons against the **12.1.5 API set**, not Classic Era / 1.12. Lua is still 5.1 plus a `.toc` with `## Interface: 120105`.

## Layout

```
CursorTooltip/           mouse-cursor tooltips; /mtt on | off | status
GatherMemory/            personal herb/ore/chest/fish tracker; /gm for options
OldManQuester/           wider quest dialog, tracker panel, bag quest-item highlight; /omq
TobarisuMap/             square movable minimap; /tmap for options
scripts/link-addon.sh    Mac: symlink addons into the Forever client
scripts/link-addon.bat   Windows: link addons into the Forever client
```

Add a new addon by creating `YourAddon/YourAddon.toc` at the repo root and listing its `.lua` files there.

## Install on Mac

Default WoW root is `/Applications/World of Warcraft`. Forever beta lives in `_classic_beta_`.

```bash
./scripts/link-addon.sh
```

That creates `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns` if needed and symlinks each addon folder at the repo root (`FolderName/FolderName.toc`). The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

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

You can also double-click `scripts\link-addon.bat`. That creates `_classic_beta_\Interface\AddOns` if needed and links each addon folder (`FolderName\FolderName.toc`) into it. The WoW folder name is case-sensitive: `AddOns`, not `Addons`.

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

Then, at the character-select screen, click **AddOns**, enable **CursorTooltip**, **GatherMemory**, **OldManQuester**, and **TobarisuMap**, and log in.

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

`/gathermemory` is an alias. Pins use the gathered item's icon (Kingsblood, Battered Chest, Firefin Snapper, and so on). Hover a pin for name, kind, skill requirement, and last seen. Settings and node locations are saved across `/reload` and logins.

## OldManQuester

Keeps the default left-docked quest and gossip windows, but scales them up so they are easier to read on ultrawide. Scales the windowed map/quest log (L) to match; the fullscreen map stays normal size. Keeps the quest tracker compact, fully transparent, and faded until you mouse over it. Also paints a high-contrast gold highlight on quest items in your bags.

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
