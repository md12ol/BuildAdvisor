# Build Advisor (BG3 mod)

Shows the strongest community build for your character and marks the right choices while you make them, in:

- **New game character creation** (Tav, Dark Urge and origin characters)
- **Withers respec** (the respec screen, then every level-up that follows)
- **Every level-up**
- **Party view** (press the hotkey any time to see the next level-up for the selected character)

It works in two ways:

1. **In the game menus:** every choice the build wants on the current screen gets a `* ` prefix (the game font draws it as a small star): race, subrace, class, subclass, background, deity, skills and expertise, feats and their own choices (for example Resilient: Constitution), spells and cantrips, spells to prepare, the spell to replace, fighting styles, manoeuvres, invocations, metamagic, Pact Boon, Draconic Ancestry, Favoured Enemy and Natural Explorer. Tiles (race, class, subclass, background, deity) and spell icons also get a rainbow outline. Point-buy rows and the ability rows of Ability Improvement show the target score in brackets, e.g. `Strength (17, +2)`.
2. **Advisor window** (F7): shows the build, a "DO THIS NOW" list for the current level, `[OK]` / `[CHANGE]` checks for your current race, class and point-buy, and the full level 1-12 plan.

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

## Settings
These are in the window: build picker (remembered for each character), *Show all builds*, *Highlight in game menus*, *Auto-open*.
Console commands (Script Extender console): `!ba_toggle`, `!ba_dump` (prints what the mod detects), `!ba_hotkey F7`.

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

To edit or add builds, change `BuildAdvisor/Mods/BuildAdvisor/ScriptExtender/Lua/Shared/Builds.lua`. Each level's `hl` list holds the exact English menu labels to star (`asi` the ability raises, `swap` a spell to replace). Check every label and level against the game's own data, then rebuild:

```bash
python tools/check_hl.py        # 0 unknown labels, 0 plan errors
python ../BG3Tools/tools/build_pak.py BuildAdvisor   # -> dist/BuildAdvisor.pak + the player package dist/BuildAdvisor/
python ../BG3Tools/tools/ci_release.py check BuildAdvisor   # what CI runs: build, zip the package, check it against INSTALL.md
```
The pak builder lives in the sibling repository [BG3Tools](https://github.com/md12ol/BG3Tools), checked out next to this one. Built paks are not committed; `dist/` is gitignored.

## Repository layout
| Path | What |
|---|---|
| `BuildAdvisor/` | the mod source as in other BG3 mod repositories: `BuildAdvisor/Mods/BuildAdvisor/` (meta.lsx, Lua, GUI); `Public/` and `Localization/` next to it when the mod needs them. This folder is what gets packed |
| `package/` | the hand-made part of the player package: `INSTALL.md` and `Media/` (Gilded Panel banner, thumbnail, marks, screenshots; list in BG3Tools `tools/release_files.py`) |
| `dist/` | local builds (gitignored): `BuildAdvisor.pak` and the player package `dist/BuildAdvisor/` (pak, `INSTALL.md`, `Handbook.html`, `Media/`), which a release zips as `BuildAdvisor-X.Y.Z.zip` |
| `docs_site/` | the docs site; `python docs_site/build_player_handbook.py` makes the player `Handbook.html` from it (with a leak check) |
| `tools/` | tests and the highlight-label checker |
| `branding/` | the logo and banner generators |
| `.luarc.json` | Lua language server settings (see Lua tooling below) |
| `nexus_description.bb` | the Nexus Mods page text (BBCode) |
| `LICENSE` | MIT |

### Lua tooling
`.luarc.json` configures [Lua Language Server](https://luals.github.io/) (the VS Code "Lua" extension) for Script Extender's Lua 5.4 and its globals. For completion of `Ext.*`, `Osi.*` and the entity types, fetch Script Extender's IDE helpers ([`ExtIdeHelpers.lua`](https://github.com/Norbyte/bg3se/blob/main/BG3Extender/IdeHelpers/ExtIdeHelpers.lua) from the bg3se repository) into `.ide/`, which `.luarc.json` already lists as a library:
```bash
curl -L --create-dirs -o .ide/ExtIdeHelpers.lua https://raw.githubusercontent.com/Norbyte/bg3se/main/BG3Extender/IdeHelpers/ExtIdeHelpers.lua
```
`.ide/` is gitignored: the helpers are Script Extender's own file under its own license, so they are not copied here.

The outline textures are built with `python ../LootAdvisor/tools/make_la_gui.py BuildAdvisor/Mods/BuildAdvisor/GUI --set build` (sibling LootAdvisor repository; recoloured from the game's own frame textures, shipped under Larian's modding terms).

## Tests
`python tools/run_tests.py` (needs `pip install lupa`) runs the mod against a mocked Script Extender. The mock covers character creation, level-up, respec, origin, party view, the highlighter (stars, outlines, point-buy and ability-improvement targets, feat choices, spell swaps, restoring) and the hotkey.

## Releases
Versions are SemVer tags `vX.Y.Z`; the first release is `v0.9.0` (set by `release-as` in
`release-please-config.json`; delete that line once v0.9.0 is out). The release workflow
(`.github/workflows/release.yml`) runs release-please on every push to `main`: it keeps one open pull request
"chore: release vX.Y.Z" with the next version and the `CHANGELOG.md` entry built from the Conventional Commit
messages. **Nothing is tagged until you merge that PR.** Merging it creates the tag and the GitHub Release; the
workflow then stamps the version into `meta.lsx` (Version64), builds the pak, zips the player package as
`BuildAdvisor-X.Y.Z.zip`, checks the zip against `INSTALL.md` and attaches it to the Release. A manual run of the workflow
(`gh workflow run release.yml -f tag=vX.Y.Z`) rebuilds and re-attaches the zip of an existing tag.
The release PR is opened by the workflow token, so GitHub does not run CI on it: merge it as an admin (branch
protection lets admins through) after checking the CHANGELOG.

**Nexus Mods upload** (optional, skipped until configured) uses Nexus Mods' official
[upload-action](https://github.com/Nexus-Mods/upload-action) and Upload API. Setup, once the mod page exists:
1. Create the mod page on Nexus Mods and upload the first file by hand (the API adds new *versions* of an existing
   file).
2. Note the mod ID (in the page URL) and the file ID (Files tab, "Advanced", or the Manage Files edit menu).
3. Create an API key at <https://www.nexusmods.com/settings/api-keys>.
4. In this repository: `gh secret set NEXUS_API_KEY`, `gh variable set NEXUS_MOD_ID --body <mod id>`,
   `gh variable set NEXUS_FILE_ID --body <file id>`.
From then on every release also uploads the zip to Nexus as a new version of that file (the old version is archived,
the Release notes become the Nexus changelog).

## Contributing
Setup, building and testing in the game for both mods: see
[CONTRIBUTING in BG3Tools](https://github.com/md12ol/BG3Tools/blob/main/CONTRIBUTING.md) (`sh setup.sh` there clones
the repositories side by side and installs the pre-push hook).

- **One branch per task**, named after its topic (`ci-setup`, `sets-page-header`, ...), cut from `main`. Nobody
  commits to `main` directly: it is protected and only takes pull requests.
- **Commits and PR titles use [Conventional Commits](https://www.conventionalcommits.org/)**: `feat:`, `fix:`,
  `docs:`, `chore:`, `refactor:`, `test:`, `ci:` (`feat!:` for a breaking change). A commit message is a subject line
  plus at most one body line. No co-author, "generated with" or other attribution lines.
- Open a pull request to `main` (`gh pr create`); the CI checks (`lint`, `tests`, `pr-title`) must be green. CI checks out the sibling
  repositories side by side and uses their branch of the same name when it exists, else `main`.
- Merge with **"Create a merge commit"** (`gh pr merge --merge`, i.e. `--no-ff`); squash and rebase merges are off so
  the branch history stays readable. The PR title becomes the merge commit subject.
- Tests that need the game's data run locally only, in the pre-push hook (see CONTRIBUTING in
  [BG3Tools](https://github.com/md12ol/BG3Tools)); it runs the full suite before every push.

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
