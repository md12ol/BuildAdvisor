# Changelog

All notable changes to Build Advisor, newest first. Versions follow [Semantic Versioning](https://semver.org/) (tags
`vX.Y.Z`). Entries are written by release-please from the Conventional Commit messages on `main` (README
"Releases"); the first release is `v0.9.0`.

## [Before 0.9.0] - what the first release contains

### Added
- 22 Patch 8 community builds (tiers S+ to A) with suggestions for every origin character.
- In-menu marks: the choices a build wants are starred in character creation, Withers respec and every level-up (race,
  class, subclass, background, deity, skills, feats, spells, fighting styles, manoeuvres, invocations, metamagic and
  more); tiles and spell icons get a rainbow outline; point-buy and ability-improvement rows show the target score.
- Advisor window (**F7**): the build, a "DO THIS NOW" list, `[OK]` / `[CHANGE]` checks and the full level 1-12 plan;
  party view for the next level-up of any character.
- Settings in the window (build picker per character, show all builds, highlighting, auto-open) and console commands.
- Player package: `BuildAdvisor.pak` with `INSTALL.md`.
- Mock Script Extender test suite (`tools/run_tests.py`), label checker against game data (`tools/check_hl.py`),
  GitHub CI.
