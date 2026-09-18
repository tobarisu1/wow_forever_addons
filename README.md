# wow_forever_addons

Personal addons for [World of Warcraft: Forever](https://github.com/tobarisu1/wow_forever_addons), developed and played on Mac.

Forever gameplay is vanilla-era (level cap 60). The client UI is Mainline: write addons against the **12.1.5 API set**, not Classic Era / 1.12. Lua is still 5.1 plus a `.toc` with `## Interface: 120105`.

Repo: https://github.com/tobarisu1/wow_forever_addons

## Layout

```
CursorTooltip/           mouse-cursor tooltips; /mtt on | off | status
GatherMemory/            personal herb/ore/chest tracker; /gm for options
scripts/link-addon.sh    symlink addons into the Forever client
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

Enable the addon on the character-select screen.

## CursorTooltip

Anchors the default GameTooltip (world units and objects) to the mouse cursor.

- `/mtt` — print the menu and current state
- `/mtt on` — enable
- `/mtt off` — disable
- `/mtt status` — print ON or OFF

`/cursortooltip` is an alias. The last on/off choice is saved across `/reload` and logins.

## GatherMemory

Remembers herbs, ore, and chests **you** gather and shows those spots on the minimap and world map. No shared spawn database.

- `/gm` — print the menu and current state
- `/gm herbs | ore | chests on | off`
- `/gm minimap | worldmap on | off`
- `/gm status`
- `/gm clear zone` — delete nodes in the current zone
- `/gm clear all` — delete every saved node

`/gathermemory` is an alias. Pins use the gathered item's icon (Kingsblood, Battered Chest, and so on). Hover a pin for name, kind, skill requirement, and last seen. Settings and node locations are saved across `/reload` and logins.

## Reload vs restart

- Lua-only edits: `/reload` in game
- TOC or new-file changes: `/reload` usually works; restart the client if it does not show up

## Interface version

TOCs use Mainline `120105` (patch 12.1.5). If the addon list marks an addon out of date, log in and run:

```
/run print(select(4, GetBuildInfo()))
```

Put that number in `## Interface:`.
