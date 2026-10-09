# Installing Build Advisor

## What is in this folder
| File | What it is |
|---|---|
| `BuildAdvisor.pak` | The mod. The only file the game needs. |
| `INSTALL.md` | This file. |
| `Handbook.html` | The player handbook: install, the marks in the game menus, the advisor window, all builds, settings, FAQ. Open it in any browser; it works offline. |
| `Media/` | Banner, thumbnail, logo marks and a screenshot, for sharing or a mod page. The game does not need them. |

`Media/` holds:
- `BuildAdvisor_banner_1920x1080.png`, `BuildAdvisor_thumbnail_1024.png`
- `BuildAdvisor_mark_128.png`, `BuildAdvisor_mark_64.png`, `BuildAdvisor_wordmark.png`
- `Screenshot_1_advisor_window_F7.jpg`

## Requirements
- Baldur's Gate 3 (Patch 8).
- [BG3 Script Extender](https://github.com/Norbyte/bg3se) v20 or newer. It is a separate project and is not included;
  [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager) installs it in one click.
- Game language English for the in-menu marks (the advisor window works in any language).

## Install with BG3 Mod Manager
1. Install Script Extender: in BG3 Mod Manager choose *Tools > Download and Extract the Script Extender*.
2. Drag `BuildAdvisor.pak` into BG3 Mod Manager (or *File > Import Mod*).
3. Move Build Advisor to the active mods list, then *Save Load Order* and *Export Load Order to Game*.
4. Start the game. If a *Mod Verification* dialog lists Build Advisor, tick it and choose Start Game.

## Install by hand
1. Install Script Extender.
2. Copy `BuildAdvisor.pak` to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\`.
3. Enable it in the load order (a mod manager is the safe way to edit `modsettings.lsx`).

## Where to find it in the game
- The advisor window opens by itself in character creation, the Withers respec and every level-up; **F7** toggles it.
- Choices the build wants are starred (`*`) in the game menus; tiles and spell icons get a rainbow outline.

## Uninstall
Disable or remove Build Advisor in the mod manager (or delete the pak from the Mods folder). Nothing is written to
your saves.
