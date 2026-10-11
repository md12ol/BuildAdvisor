# Build Advisor (BG3 mod)

Shows the strongest community build for your character and marks the right choices while you make them, in:

- **New game character creation** (Tav, Dark Urge and origin characters)
- **Withers respec** (the respec screen, then every level-up that follows)
- **Every level-up**
- **Party view** (press the hotkey any time to see the next level-up for the selected character)

## Requirements
- [BG3 Script Extender](https://github.com/Norbyte/bg3se). BG3 Mod Manager can install it. The stars and outlines in the
  game's menus need v33 or newer; on v32 the advisor window works. Until v33 is a normal release, get it from the Devel channel: create a file
  `ScriptExtenderUpdaterConfig.json` in the game's `bin` folder containing `{"UpdateChannel": "Devel"}`,
  then start the game once. Delete that file to go back to normal releases.
- Game language set to English. The in-menu highlighting matches English labels; the advisor window works in any language.

## Install
1. Install Script Extender.
2. Download `BuildAdvisor-X.Y.Z.zip` from the [Releases](https://github.com/md12ol/BuildAdvisor/releases) page (or the mod's Nexus Mods page) and import its `BuildAdvisor.pak` (see [`INSTALL.md`](package/INSTALL.md)) with BG3 Mod Manager, or copy it to
   `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\`. Then enable it in the mod manager and export the load order.
3. Start the game. The window opens on its own in character creation and level-up. **F7** toggles it (F9 = photo mode and F10 = hide UI are game keys).

**Linux and Steam Deck (Proton):** not tested yet. [`INSTALL.md`](package/INSTALL.md#linux-and-steam-deck-untested)
has a *Linux and Steam Deck (untested)* section: the Script Extender launch option and where the game's folders are
inside the Proton prefix. Reports are welcome in [LootAdvisor#80](https://github.com/md12ol/LootAdvisor/issues/80).

## How to use it
It works in two ways:

1. **In the game menus:** every choice the build wants on the current screen gets a `* ` prefix (the game font draws it as a small star): race, subrace, class, subclass, background, deity, skills and expertise, feats and their own choices (for example Resilient: Constitution), spells and cantrips, spells to prepare, the spell to replace, fighting styles, manoeuvres, invocations, metamagic, Pact Boon, Draconic Ancestry, Favoured Enemy and Natural Explorer. Tiles (race, class, subclass, background, deity) and spell icons also get a rainbow outline. Point-buy rows and the ability rows of Ability Improvement show the target score in brackets, e.g. `Strength (17, +2)`; a row too long for its name column uses the game's short name, e.g. `CON (16, +1)`.
2. **Advisor window** (F7): shows the build, a short "Do this now" list for the current screen, one green line for the choices that already match the plan plus a row for each one to change, and folded sections for the build's details and the full level 1-12 plan. Below them, with
   [Loot Advisor](https://github.com/md12ol/LootAdvisor) installed, three folded **gear sets** for the build (Loot
   Advisor's sets 1-3, each a list of items per act; items you have and items that count only if you already have them
   are marked), read from Loot Advisor while the game runs; without it, one line saying where the gear sets come from.
   Loot Advisor's sets are made for these builds: a character on none of them gets the closest build's items there. In creation, respec and level-up it sits beside the game's left selection panel, as tall as that panel.

## Settings
These are in the window: build picker (remembered for each character), *Show all builds*, *Highlight in game menus*, *Auto-open*.
Console commands (Script Extender console): `!ba_toggle`, `!ba_dump` (prints what the mod detects), `!ba_hotkey F7`.
More options (hotkey, text size, the build picked per character) are in `BuildAdvisor_settings.json` in the Script
Extender folder; `Handbook.html` in the download, chapter "Settings", lists them.

## Builds included (Patch 8 meta)
| Build | Tier | Start class | Suggested for |
|---|---|---|---|
| Sorcadin – Vengeance Paladin 6 / Shadow Sorcerer 6 | S+ | Paladin | Minthara; 2nd for Lae'zel |
| Pure Paladin 12 (Oathbreaker) | S+ | Paladin | 2nd for Minthara |
| Bardadin – Paladin 2 / Swords Bard 10 | S | Paladin | |
| Lockadin – Paladin 5 / Hexblade Warlock 7 | S | Paladin | 2nd for Wyll |
| Path of Giants Barbarian 12 | S | Barbarian | Karlach |
| Throwzerker – Berserker 10 / Fighter 2 | S | Barbarian | 2nd for Karlach and the Dark Urge |
| Throwzerker Thief – Berserker 7 / Thief 3 / Fighter 2 | S+ | Barbarian | 3rd for Karlach |
| Throw-Thief – Berserker 5 / Thief 4 / Champion 3 | S+ | Barbarian | the Dark Urge |
| Tavern Brawler Open Hand Monk 12 | S | Monk | 2nd for Halsin |
| Battle Master Fighter 12 (Giantslayer + advantage) | S+ | Fighter | Lae'zel |
| Battle Master Fighter 12 | S | Fighter | 2nd for Minsc |
| Gloom Stalker 5 / Assassin 4 / Battle Master 3 | S | Ranger | Minsc; 2nd for Astarion, Jaheira |
| Gloom Stalker 5 / Battle Master 3 / Thief 4 (hand crossbows) | S+ | Ranger | Astarion |
| Light Domain Cleric 9 / Sorcerer 3 (Quickened) | S | Cleric | Shadowheart |
| Light Domain Cleric 12 | S | Cleric | 2nd for Shadowheart |
| Evocation Wizard 10 / Tempest Cleric 2 | S | Wizard | Gale |
| Storm Sorcerer 10 / Tempest Cleric 2 | S | Sorcerer | 2nd for Gale |
| Sorlock – Fiend Warlock 2 / Draconic Sorcerer 10 | A | Warlock | Wyll |
| Hexblade Sorlock – Hexblade 2 / Draconic Sorcerer 8 / Fighter 2 | S | Sorcerer | 3rd for Wyll |
| Evocation Wizard 12 | A | Wizard | |
| Circle of the Moon Druid 12 | A | Druid | Halsin |
| Circle of the Stars Druid 12 | A | Druid | Jaheira |

## Known limits
- Every game call is wrapped, so a game patch makes a feature fail quietly instead of crashing. If something doesn't show, run `!ba_dump` in the SE console.
- Highlighting changes the text and colour of matching labels. If a menu looks wrong, untick *Highlight in game menus*. The window still works on its own.
- If the game or mod manager rejects the generated pak, pack the `BuildAdvisor` folder (its `Mods/`) with LSLib/Divine or BG3 Modder's Multitool.

## Sources
- [Best BG3 classes 2026 tier list](https://everythingedinburgh.com/games/gaming/best-bg3-classes/)
- [AlcastHQ – Top 10 builds for Patch 8](https://alcasthq.com/top-10-builds-for-bg3-patch-8/), [AlcastHQ Sorcadin](https://alcasthq.com/bg3-sorcerer-paladin-multiclass-build/)
- [Switchblade Gaming – BG3 multiclass guide 2026](https://www.switchbladegaming.com/baldurs-gate-3/multiclass-guide/)
- [HackTheMinotaur – best builds / multiclass](https://hacktheminotaur.com/baldurs-gate-3/baldurs-gate-3-best-builds/)
- [PlayNews – 10 best single-class builds 2026](https://www.playnews.gg/en/guides/baldur-s-gate-3-the-10-best-single-class-builds-2026-paladin-barbarian-warlock-and-company-without-touching-multiclass)
- [KeenGamer – optimized origin builds](https://www.keengamer.com/articles/guides/optimized-builds-for-the-baldurs-gate-3-origin-characters/)
## Support
Bugs and questions: [open an issue](https://github.com/md12ol/BuildAdvisor/issues). Say which version of Build Advisor
and of Script Extender you run; the output of `!ba_dump` in the Script Extender console helps.

## Developing
Repository layout, adding builds, tests, building and contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md). How a
version is released: [`RELEASING.md`](RELEASING.md). Licence: MIT ([`LICENSE`](LICENSE)).
