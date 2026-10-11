# Contributing to Build Advisor

Setup, building and testing in the game for both mods: see
[CONTRIBUTING in BG3Tools](https://github.com/md12ol/BG3Tools/blob/main/CONTRIBUTING.md) (`sh setup.sh` there clones
the repositories side by side and installs the pre-push hook).

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

## Lua tooling
`.luarc.json` configures [Lua Language Server](https://luals.github.io/) (the VS Code "Lua" extension) for Script Extender's Lua 5.4 and its globals. For completion of `Ext.*`, `Osi.*` and the entity types, fetch Script Extender's IDE helpers ([`ExtIdeHelpers.lua`](https://github.com/Norbyte/bg3se/blob/main/BG3Extender/IdeHelpers/ExtIdeHelpers.lua) from the bg3se repository) into `.ide/`, which `.luarc.json` already lists as a library:
```bash
curl -L --create-dirs -o .ide/ExtIdeHelpers.lua https://raw.githubusercontent.com/Norbyte/bg3se/main/BG3Extender/IdeHelpers/ExtIdeHelpers.lua
```
`.ide/` is gitignored: the helpers are Script Extender's own file under its own license, so they are not copied here.

The outline textures are built with `python ../LootAdvisor/tools/make_la_gui.py BuildAdvisor/Mods/BuildAdvisor/GUI --set build` (sibling LootAdvisor repository; recoloured from the game's own frame textures, shipped under Larian's modding terms).

## Adding or editing builds
To edit or add builds, change `BuildAdvisor/Mods/BuildAdvisor/ScriptExtender/Lua/Shared/Builds.lua`. Each level's `hl` list holds the exact English menu labels to star (`asi` the ability raises, `swap` a spell to replace). Check every label and level against the game's own data, then rebuild. `check_hl.py` reads the game's paks and the
English localisation and stats that the sibling `../LootAdvisor` extracts, so run Loot Advisor's Rebuild (at least
`build_cache.py` and `stats.py`) first; a new build also needs a profile in `../LootAdvisor/tools/build_profiles.py`:

```bash
python tools/check_hl.py        # 0 unknown labels, 0 plan errors, 0 spell icon errors
python ../BG3Tools/tools/build_pak.py BuildAdvisor   # -> dist/BuildAdvisor.pak + the player package dist/BuildAdvisor/
python ../BG3Tools/tools/ci_release.py check BuildAdvisor   # what CI runs: build, zip the package, check it against INSTALL.md
```
The pak builder lives in the sibling repository [BG3Tools](https://github.com/md12ol/BG3Tools), checked out next to this one. Built paks are not committed; `dist/` is gitignored.

## Tests
`python tools/run_tests.py` (needs `pip install lupa`) runs the mod against a mocked Script Extender (`tools/mock_test.lua`,
`tools/ui_gate_test.lua`; add a scenario there for new behaviour). The mock covers character creation, level-up, respec, origin, party view, the highlighter (stars, outlines, spell icons as each spell list and picked / prepared row builds them, point-buy and ability-improvement targets, feat choices, spell swaps, restoring), the hotkey, the window's content (no repeated facts, short locked race, a row per choice to change) and its placement (beside the game's left panel, a move by the player kept).

## Branches, commits and pull requests
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
