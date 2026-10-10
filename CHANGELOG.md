# Changelog

All notable changes to Build Advisor, newest first. Versions follow [Semantic Versioning](https://semver.org/) (tags
`vX.Y.Z`). Entries are written by release-please from the Conventional Commit messages on `main` (README
"Releases"); the first release is `v0.9.0`.

## 0.9.0 (2026-10-10)


### Features

* 16:9 mod manager logo and publish thumbnail ([dc21c48](https://github.com/md12ol/BuildAdvisor/commit/dc21c482293763710cb9747250465fb9b4147b86))
* **branding:** render a 16:9 mod manager logo ([4aaa10f](https://github.com/md12ol/BuildAdvisor/commit/4aaa10f7e296f7e2d2076287c36a8e26311c41e8))
* **builds:** make Light Cleric 9 / Sorcerer 3 Shadowheart's first build ([08562db](https://github.com/md12ol/BuildAdvisor/commit/08562db58d007d0ed4cb26b357f3a58c8763b105))
* **builds:** make Light Cleric 9 / Sorcerer 3 Shadowheart's first build ([e4a8ef6](https://github.com/md12ol/BuildAdvisor/commit/e4a8ef61c9650e0661052be14bd065fba713fdd4))
* gear sets from Loot Advisor in the advisor window ([e48fcca](https://github.com/md12ol/BuildAdvisor/commit/e48fccabb5e9e79a47e76f1e79305a3981a78bb0))
* gear sets from Loot Advisor in the advisor window, three folded sets with a list per act ([c3311f1](https://github.com/md12ol/BuildAdvisor/commit/c3311f116e283d36a3972b24be531b290ed31bbd))
* mod.io publishing prep ([18acf80](https://github.com/md12ol/BuildAdvisor/commit/18acf80e04c7c15b9f1b11debb86c6dc65246c33))
* mod.io publishing prep ([5feee97](https://github.com/md12ol/BuildAdvisor/commit/5feee9763a8aececd1016fa3b587bd8922597409))
* **package:** player handbook generator; complete the install folder ([b48f7d3](https://github.com/md12ol/BuildAdvisor/commit/b48f7d3db843ed380e96e6dc7b89231696601157))
* ship the 16:9 logo as the mod's publish thumbnail ([a0aeae6](https://github.com/md12ol/BuildAdvisor/commit/a0aeae630e8aba870c417b49153837665ebb414a))
* tidier advisor window docked beside the game's selection panel ([70711e7](https://github.com/md12ol/BuildAdvisor/commit/70711e7a573f8b028a0a64652467ff6e35710d15))
* tidier advisor window docked beside the game's selection panel ([16a055c](https://github.com/md12ol/BuildAdvisor/commit/16a055c64b2adbb6708094a6255ad5d4160073a3))


### Bug Fixes

* hide the advisor window while the game's pause menu is open ([5a65cfc](https://github.com/md12ol/BuildAdvisor/commit/5a65cfc0090548b626f6e5db9c5aa34592048424))
* **mod:** draw stars and outlines in the game menus again ([d5fe2bc](https://github.com/md12ol/BuildAdvisor/commit/d5fe2bc3a38393c5dc914957e9d8bef973970085))
* **mod:** draw stars and outlines in the game menus again ([466a777](https://github.com/md12ol/BuildAdvisor/commit/466a7779ce4c7d129a77620f0b9d40a85cf313ee))
* **mod:** draw the menu stars only from Ext.UI.Defer ([18cccaa](https://github.com/md12ol/BuildAdvisor/commit/18cccaa2cbb1c9e97e42befd81fbd42d09843886))
* **mod:** draw the menu stars only from Ext.UI.Defer ([aa226f8](https://github.com/md12ol/BuildAdvisor/commit/aa226f855e4324c0849d24568b032cdfc5211d46))
* **mod:** hide the advisor window while the game's pause menu is open ([229220d](https://github.com/md12ol/BuildAdvisor/commit/229220d21bdee3216a51fc1ac8ef4e815d06befd))
* **mod:** set the mod author to Michael Dubé ([b70011a](https://github.com/md12ol/BuildAdvisor/commit/b70011aa6a32746233dbd24192ef200210a710f5))
* **mod:** set the mod author to Michael Dubé ([cf00bbe](https://github.com/md12ol/BuildAdvisor/commit/cf00bbef5bd7977335eb1d564d73823aabeea522))
* ring every planned spell icon in every spell list and picked row ([3ef20b1](https://github.com/md12ol/BuildAdvisor/commit/3ef20b1616e8f7973dd75478c8eebb8d7ba8e3c8))
* ring every planned spell icon in every spell list and picked row ([5a908b9](https://github.com/md12ol/BuildAdvisor/commit/5a908b9261f287d944d44edf670e2271bd4d7d27))
* step aside for the game's message boxes and fit long point-buy targets ([8181dec](https://github.com/md12ol/BuildAdvisor/commit/8181decc2b1e207dbd295cab536e1c36e041b50b))
* step aside for the game's message boxes and fit long point-buy targets ([433d7c1](https://github.com/md12ol/BuildAdvisor/commit/433d7c13a9b5f360cb99f42d5d8ef3dd373cf027))

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
