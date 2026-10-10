-- Offline test: mocks the Script Extender API and runs the mod through
-- character creation, level up, respec, party view and the in-menu highlighter (stars, rainbow outlines of tiles
-- and spell icons, point-buy and ability-improvement targets, feat sub-choices, spell swaps, restore on close).
local ROOT = ...
local LUA = ROOT .. "/BuildAdvisor/Mods/BuildAdvisor/ScriptExtender/Lua/"

------------------------------------------------------------------ mock static data
local function ts(s) return { Get = function() return s end, Handle = { Handle = s } } end
local static = {
  ClassDescription = {
    pal = { Name = "Paladin", DisplayName = ts("Paladin") },
    sor = { Name = "Sorcerer", DisplayName = ts("Sorcerer") },
    clr = { Name = "Cleric", DisplayName = ts("Cleric") },
    rog = { Name = "Rogue", DisplayName = ts("Rogue") },
    ven = { Name = "Vengeance", DisplayName = ts("Oath of Vengeance"), ParentGuid = "pal" },
    wiz = { Name = "Wizard", DisplayName = ts("Wizard") },
    evo = { Name = "EvocationSchool", DisplayName = ts("Evocation"), ParentGuid = "wiz" },
    stm = { Name = "StormSorcery", DisplayName = ts("Storm Sorcery"), ParentGuid = "sor" },
  },
  Race = { horc = { Name = "HalfOrc", DisplayName = ts("Half-Orc") }, human = { Name = "Human", DisplayName = ts("Human") },
           helf = { Name = "HighElf", DisplayName = ts("High Elf") } },
  Origin = { tav = { Name = "Generic" }, sh = { Name = "ShadowHeart" } },
}

------------------------------------------------------------------ mock IMGUI
local log = {}
local function node(kind, label)
  local n = { kind = kind, Label = label, children = {} }
  local mt = {}
  mt.__index = function(t, k)
    if k:sub(1, 3) == "Add" then
      return function(self, l)
        local c = node(k:sub(4), l)
        table.insert(self.children, c)
        if k == "AddText" or k == "AddBulletText" or k == "AddSeparatorText" then table.insert(log, k:sub(4) .. ": " .. tostring(l)) end
        return c
      end
    end
    return function() end
  end
  return setmetatable(n, mt)
end

------------------------------------------------------------------ mock Noesis tree
local function nel(text, kids)
  local e = { Text = text, kids = kids or {}, VisualChildrenCount = #(kids or {}) }
  function e:VisualChild(i) return self.kids[i] end
  return e
end
local uiRoot = nel(nil, {
  nel("Half-Orc"), nel("Human"), nel(nil, { nel("Paladin"), nel("Sorcerer"), nel("Oath of Vengeance") }),
  nel("Athletics"), nel("Stealth"), nel("Great Weapon Master"),
})
-- list item whose label TextBlock is bound (Text reads nil); the name lives on the DataContext
local boundTB = nel("[ForceUpdate]")
local item = nel(nil, { nel(nil, { boundTB }) })
item.Type = "ListBoxItem"; item.DataContext = { Name = "hdeadbeefg1234g", IDString = "Intimidation" }
table.insert(uiRoot.kids, item); uiRoot.VisualChildrenCount = #uiRoot.kids
-- point-buy row (ls.VMAbility DataContext) with its name and value TextBlocks
local strName, strVal = nel("Strength"), nel("17")
local strBtn = nel(nil); strBtn.Type = "ls.LSRepeatButton"
local strRow = nel(nil, { nel(nil, { strName, strVal, strBtn }) })
strRow.Type = "ContentPresenter"; strRow.DataContext = { Type = "ls.VMAbility", Ability = "Strength", BaseValue = 15 }
local dexName = nel("Dexterity")
local dexBtn = nel(nil); dexBtn.Type = "ls.LSRepeatButton"
local dexRow = nel(nil, { dexName, nel("12"), dexBtn })
-- summary panel row: same view model, abbreviated label -> must stay untouched
local sumName = nel("STR") -- the summary panel abbreviates
local sumRow = nel(nil, { sumName }); sumRow.Type = "ContentPresenter"
sumRow.DataContext = { Type = "ls.VMAbility", Ability = "Strength", BaseValue = 15 }
table.insert(uiRoot.kids, sumRow)
-- skill proficiency summary + its Change button
local skillSummary, changeBtn = nel("Religion, Insight, Intimidation"), nel("Change")
table.insert(uiRoot.kids, skillSummary); table.insert(uiRoot.kids, changeBtn)
-- skill picker row: name and value TextBlocks are both bound; only the name may be marked
local pickName, pickValue = nel("[ForceUpdate]"), nel("[ForceUpdate]")
local pickIcon = nel(nil); pickIcon.Type = "Image"
local pickGrid = nel(nil, { pickName }); pickGrid.Type = "Grid"
-- value column row: same view model, no icon
local valRow = nel(nil, { pickValue }); valRow.Type = "ContentPresenter"
valRow.DataContext = { Type = "ls.VMCharacterCreationSkill", Skill = "Athletics" }
table.insert(uiRoot.kids, valRow)
local pickRow = nel(nil, { pickIcon, pickGrid }); pickRow.Type = "ContentPresenter"
pickRow.DataContext = { Type = "ls.VMCharacterCreationSkill", Skill = "Athletics" }
table.insert(uiRoot.kids, pickRow)
dexRow.Type = "ContentPresenter"; dexRow.DataContext = { Type = "ls.VMAbility", Ability = "Dexterity", BaseValue = 12 }
table.insert(uiRoot.kids, strRow); table.insert(uiRoot.kids, dexRow); uiRoot.VisualChildrenCount = #uiRoot.kids

------------------------------------------------------------------ mock entities
local entities = {}
local subs = { Tick = {}, KeyInput = {}, SessionLoaded = {}, ResetCompleted = {} }
local function event(name) return { Subscribe = function(_, f) table.insert(subs[name], f) end } end
local now = 0
local files = {}
local deferred = {}

Ext = {
  Require = function(p) return dofile(LUA .. p) end,
  StaticData = { Get = function(g, kind) return static[kind] and static[kind][g] end },
  Loca = { GetTranslatedString = function(h) return h == "hdeadbeefg1234g" and "Intimidation" or h end },
  Entity = { GetAllEntitiesWithComponent = function(c) return entities[c] or {} end },
  IMGUI = { NewWindow = function(t) return node("Window", t) end },
  UI = { GetRoot = function() return uiRoot end, Instantiate = function() return {} end,
         Defer = function(f) table.insert(deferred, f) end }, -- run at the end of tick(), like the next UI update
  IO = { LoadFile = function(p) return files[p] end, SaveFile = function(p, s) files[p] = s; return true end },
  Json = { Parse = function() return {} end, Stringify = function() return "{}" end },
  Utils = { MonotonicTime = function() return now end, Print = print, PrintWarning = print, PrintError = print },
  Events = { Tick = event("Tick"), KeyInput = event("KeyInput"), SessionLoaded = event("SessionLoaded"), ResetCompleted = event("ResetCompleted") },
}
Ext.RegisterConsoleCommand = function() end
_D = print

dofile(LUA .. "BootstrapClient.lua")
for _, f in ipairs(subs.SessionLoaded) do f() end

local function tick()
  now = now + 1100
  for _, f in ipairs(subs.Tick) do f() end
  local q = deferred; deferred = {}
  for _, f in ipairs(q) do f() end
end
local function dump(title)
  print("\n==== " .. title .. " ====")
  for _, l in ipairs(log) do print(l) end
  log = {}
end
local fails = 0
local function expect(cond, msg) if not cond then fails = fails + 1; print("FAIL: " .. msg) else print("ok: " .. msg) end end

-- 1) New game: Tav, Human Paladin, wrong abilities
local abil = { 0, 10, 10, 10, 10, 10, 10 }
entities.CCCharacterDefinition = { {
  CCCharacterDefinition = { Definition = {
    Name = "Tav", Abilities = abil,
    Definition = { Race = "human", Subrace = "", Origin = "tav" },
    LevelUpData = { Class = "pal", SubClass = "", Upgrades = { AbilityBonuses = {} } },
  } } } }
tick(); dump("Character creation: Human Paladin")
expect(BA.Current.build.id == "sorcadin", "Paladin start recommends Sorcadin first")
expect(BA.UI.window.Open == true, "window auto-opened")
expect(uiRoot.kids[1].Text == "* Half-Orc", "Half-Orc highlighted in menu")
expect(uiRoot.kids[2].Text == "Human", "Human not highlighted")
expect(uiRoot.kids[3].kids[1].Text == "* Paladin", "Paladin highlighted")
expect(uiRoot.kids[3].kids[3].Text == "* Oath of Vengeance", "Oath of Vengeance highlighted")
expect(uiRoot.kids[4].Text == "* Athletics", "Athletics highlighted")
expect(boundTB.Text == "* Intimidation", "bound list-item label highlighted via DataContext")
expect(strName.Text == "Strength (17, +2)", "point-buy row shows target and racial bonus: " .. tostring(strName.Text))
expect(dexName.Text == "Dexterity (10)", "point-buy row shows target without bonus: " .. tostring(dexName.Text))
expect(strVal.Text == "17", "point-buy value untouched")
expect(sumName.Text == "STR", "summary panel STR label untouched")
expect(changeBtn.Text == "* Change", "skill Change button marked when a planned skill is missing")
expect(pickName.Text == "* Athletics" and pickValue.Text == "[ForceUpdate]", "skill picker marks the name only")
skillSummary.Text = "Athletics, Intimidation, Persuasion, Insight, Religion"
tick()
expect(changeBtn.Text == "Change", "skill Change button unmarked once skills match")

-- real layout: VMSkill items (IsProficient) followed by an ls.LSToggleButton with a bound label
for i = #uiRoot.kids, 1, -1 do if uiRoot.kids[i] == skillSummary or uiRoot.kids[i] == changeBtn then table.remove(uiRoot.kids, i) end end
local function skillVM(name, prof) local e = nel(nil, { nel("[ForceUpdate]") }); e.Type = "ContentPresenter"; e.DataContext = { Type = "ls.VMSkill", Skill = name, IsProficient = prof }; return e end
local toggleLabel = nel("[ForceUpdate]")
local toggle = nel(nil, { nel(nil, { toggleLabel }) }); toggle.Type = "ls.LSToggleButton"; toggle.kids[1].Type = "Grid"
local box = nel(nil, { skillVM("Athletics", true), skillVM("Intimidation", true), skillVM("Persuasion", false), skillVM("Insight", true), toggle }); box.Type = "StackPanel"
table.insert(uiRoot.kids, box); uiRoot.VisualChildrenCount = #uiRoot.kids
tick()
expect(toggleLabel.Text == "* Change", "Change toggle marked from VMSkill proficiencies: " .. tostring(toggleLabel.Text))
box.kids[3].DataContext.IsProficient = true
tick()
expect(toggleLabel.Text == "Change", "Change toggle unmarked once VMSkill has every planned skill")
local bad = 0
for _, c in ipairs(BA.Current.analysis.checks) do if not c.ok then bad = bad + 1 end end
expect(bad >= 2, "race + abilities flagged as CHANGE")

-- 2) Fix race and abilities -> checks pass
entities.CCCharacterDefinition[1].CCCharacterDefinition.Definition.Definition.Race = "horc"
local d = entities.CCCharacterDefinition[1].CCCharacterDefinition.Definition
d.Abilities = { 0, 7, 2, 6, 0, 0, 7 } -- the game stores points bought above the base 8
d.LevelUpData.Upgrades.AbilityBonuses = { { Bonuses = { "Strength", "Charisma" }, BonusAmounts = { 2, 1 } } }
tick(); dump("Character creation: fixed")
local allOk = true
for _, c in ipairs(BA.Current.analysis.checks) do if not c.ok then allOk = false; print("  not ok: " .. c.text) end end
expect(allOk, "all checks OK after following advice")
entities.CCCharacterDefinition = nil

-- 3) Level up to level 7 (Paladin 6 -> should take Sorcerer)
local char = { EocLevel = { Level = 6 }, Classes = { Classes = { { ClassUUID = "pal", SubClassUUID = "ven", Level = 6 } } },
               Origin = { Origin = "Generic" }, Race = { Race = "horc" }, DisplayName = { Name = ts("Tav") } }
entities.CCLevelUpDefinition = { { CCLevelUpDefinition = { Character = char, LevelUp = { LevelUpData = { Class = "pal", SubClass = "" } } } } }
uiRoot.kids[3].kids[2].Text = "Sorcerer"
tick(); dump("Level up 6 -> 7, picked Paladin")
expect(BA.Current.analysis.step.cls == "Sorcerer", "level 7 step is Sorcerer")
expect(uiRoot.kids[3].kids[2].Text == "* Sorcerer", "Sorcerer highlighted at level 7")
expect(uiRoot.kids[1].Text == "Half-Orc", "Half-Orc highlight restored after leaving CC")
expect(uiRoot.kids[3].kids[1].Text == "Paladin", "Paladin highlight removed")
expect(boundTB.Text == "Intimidation", "bound list-item label restored")
expect(strName.Text == "Strength" and dexName.Text == "Dexterity", "point-buy names restored after leaving CC")
entities.CCLevelUpDefinition = nil

-- 4) Origin: Shadowheart respec
entities.CCRespecDefinition = { { CCRespecDefinition = { Definition = {
  Name = "Shadowheart", Abilities = { 0, 10, 13, 14, 10, 17, 8 },
  Definition = { Race = "helf", Subrace = "", Origin = "sh" },
  LevelUpData = { Class = "clr", SubClass = "", Upgrades = { AbilityBonuses = {} } } } } } }
tick(); dump("Withers respec: Shadowheart")
expect(BA.Current.build.id == "lightquick", "Shadowheart -> Light Cleric / Sorcerer (lightquick first)")
entities.CCRespecDefinition = nil

-- 5) Party view (Astarion, rogue 3)
entities.ClientControl = { { EocLevel = { Level = 3 }, Classes = { Classes = { { ClassUUID = "rog", SubClassUUID = "", Level = 3 } } },
  Origin = { Origin = "Astarion" }, Race = { Race = "helf" }, DisplayName = { Name = ts("Astarion") }, Stats = { Abilities = { 0, 8, 17, 14, 13, 13, 10 } } } }
tick(); dump("Party: Astarion")
expect(BA.Current.build.id == "thx", "Astarion -> Gloom Stalker Thief hand crossbows (thx)")
expect(#BA.Current.analysis.warnings == 1, "class split warning (Rogue 3 vs Ranger 3)")
expect(BA.UI.window.Open == false, "window auto-hides when the selection screen closes")

-- 6) Hotkey toggles (unchanged by auto show / hide)
local function hotkey() for _, f in ipairs(subs.KeyInput) do f({ Event = "KeyDown", Key = "F7", Repeat = false }) end end
hotkey(); expect(BA.UI.window.Open == true, "F7 opens window in party view")
tick(); expect(BA.UI.window.Open == true, "party view does not auto-hide an F7-opened window")
hotkey(); expect(BA.UI.window.Open == false, "F7 closes window")

------------------------------------------------------------------ new highlight targets (outlines, rows, swaps)
-- element with an x:Name, Noesis properties (GetProperty / SetProperty) and children
local function pel(ty, name, kids, props)
  local e = nel(nil, kids)
  e.Type, e.Name, e.props = ty, name, props or {}
  function e:GetProperty(k) return self.props[k] end
  function e:SetProperty(k, v) self.props[k] = v end
  return e
end
local RING, ICON, CLEAR = { brush = "ring" }, { brush = "icon" }, { brush = "clear" }
local assets = pel("ui::UIWidget", "BuildAdvisorRes", { pel("Grid", "BA_Holder", {
  pel("Rectangle", "BA_TileRing", nil, { Fill = RING }), pel("Rectangle", "BA_IconRing", nil, { Fill = ICON }),
  pel("Rectangle", "BA_Clear", nil, { Fill = CLEAR }) }) })
-- a tile of the race / class / background / deity grids (CustomIconTemplate / ClassIconTemplate)
local function tile(vm)
  local label = nel("[ForceUpdate]")
  local grid = pel("Grid", nil, { pel("Rectangle", "icon"), pel("ls.LSNineSliceImage", "frame") })
  local panel = nel(nil, { grid, label }); panel.Type = "StackPanel"
  local cp = nel(nil, { panel }); cp.Type = "ContentPresenter"; cp.DataContext = vm
  local item = nel(nil, { cp }); item.Type = "ListBoxItem"; item.DataContext = vm
  return item, label, grid
end
-- a spell / cantrip icon (SpellIconTemplate: Border "border" with the spell's view model, 4 px BorderBrush)
local function spellIcon(name)
  local b = pel("Border", "border", { pel("Grid", "base", { pel("Rectangle"), nel("III") }) }, { BorderBrush = CLEAR })
  b.DataContext = { Type = "ls.VMCharacterCreationSpell", Name = name }
  return b
end
-- a passive / feat-choice row (SelectableEnhancement: check box images, name TextBlock, collapsed source TextBlock)
local function passiveRow(name)
  local txt, src = nel("[ForceUpdate]"), nel("")
  local img = nel(nil); img.Type = "Image"
  local grid = nel(nil, { img, txt, src }); grid.Type = "Grid"
  local cp = nel(nil, { grid }); cp.Type = "ContentPresenter"
  cp.DataContext = { Type = "ls.VMCharacterCreationPassive", Name = name }
  return cp, txt, src
end
-- an ability row with - / + buttons (point buy, Ability Improvement and feat ability choices)
local function abilityRow(ability)
  local name = nel("[ForceUpdate]")
  local ctl = nel(nil, { name }); ctl.Type = "Control"
  local minus, plus = nel(nil), nel(nil); minus.Type = "ls.LSButton"; plus.Type = "ls.LSButton"
  local panel = nel(nil, { ctl, minus, nel("14"), plus }); panel.Type = "StackPanel"
  local row = nel(nil, { panel }); row.Type = "ContentPresenter"
  row.DataContext = { Type = "ls.VMAbility", Ability = ability, BaseValue = 14 }
  return row, name
end
local function setRoot(kids) uiRoot = nel(nil, kids); uiRoot.Type = "ls.UICanvas" end

entities.ClientControl = nil
BA.HL.Clear()

-- 8) Character creation: Tav Cleric -> Light Cleric. Background grid + deity grid tiles are starred and outlined.
local soldierItem, soldierLabel, soldierGrid = tile({ Type = "ls.VMSelectable", Name = "Soldier" })
local acolyteItem, acolyteLabel, acolyteGrid = tile({ Type = "ls.VMSelectable", Name = "h0ac01e7eg0001g" })
local lathItem, lathLabel, lathGrid = tile({ Type = "ls.VMSelectable", Name = "Lathander" })
local lightTile, lightTileLabel, lightTileGrid = tile({ Type = "ls.VMSelectableClass", Name = "Light Domain", ShortName = "Light" })
local guidance = spellIcon("Guidance")
setRoot({ assets, soldierItem, acolyteItem, lathItem, lightTile, guidance, nel("Shield"), nel("Shield of Faith") })
local origLoca = Ext.Loca.GetTranslatedString
Ext.Loca.GetTranslatedString = function(h) if h == "h0ac01e7eg0001g" then return "Acolyte" end return origLoca(h) end
entities.CCCharacterDefinition = { {
  CCCharacterDefinition = { Definition = {
    Name = "Tav", Abilities = { 0, 0, 6, 7, 0, 7, 2 },
    Definition = { Race = "helf", Subrace = "", Origin = "tav" },
    LevelUpData = { Class = "clr", SubClass = "", Upgrades = { AbilityBonuses = {} } },
  } } } }
tick(); dump("Character creation: Tav Cleric")
expect(BA.Current.build.id == "lightquick", "Cleric start recommends the Light Cleric / Sorcerer build first")
expect(acolyteLabel.Text == "* Acolyte", "background tile starred via its loca handle: " .. tostring(acolyteLabel.Text))
expect(acolyteGrid.props.Background == RING, "background tile outlined with the rainbow ring")
expect(soldierLabel.Text == "[ForceUpdate]" and soldierGrid.props.Background == nil, "other background tile untouched")
expect(lathLabel.Text == "* Lathander" and lathGrid.props.Background == RING, "deity tile starred and outlined")
expect(lightTileLabel.Text == "* Light" and lightTileGrid.props.Background == RING, "subclass tile starred with its short name")
expect(guidance.props.BorderBrush == ICON, "planned cantrip icon outlined")
expect(uiRoot.kids[7].Text == "Shield" and uiRoot.kids[8].Text == "* Shield of Faith", "exact labels: Shield of Faith starred, Shield not")
-- leaving the screen restores everything
entities.CCCharacterDefinition = nil
tick()
expect(acolyteLabel.Text ~= "* Acolyte" and acolyteGrid.props.Background == CLEAR, "background tile restored on leaving")
expect(guidance.props.BorderBrush == CLEAR, "spell icon border restored on leaving")
expect(lathGrid.props.Background == CLEAR, "deity tile restored")
Ext.Loca.GetTranslatedString = origLoca

-- 9) Level up Gale 5 -> 6 (tempestevoker: Cleric 1). "Light" is wanted as a cantrip but must not star the Light
--    Domain tile; Tempest Domain is starred with its short name; the deity tile appears for the first Cleric level.
local tempTile, tempLabel, tempGrid = tile({ Type = "ls.VMSelectableClass", Name = "Tempest Domain", ShortName = "Tempest" })
local lightT, lightLabel, lightGrid = tile({ Type = "ls.VMSelectableClass", Name = "Light Domain", ShortName = "Light" })
local talos, talosLabel = tile({ Type = "ls.VMSelectable", Name = "Talos" })
local lightIcon, resistIcon, sacredIcon = spellIcon("Light"), spellIcon("Resistance"), spellIcon("Sacred Flame")
setRoot({ assets, tempTile, lightT, talos, lightIcon, resistIcon, sacredIcon, nel("Lightning Bolt") })
local gale = { EocLevel = { Level = 5 }, Classes = { Classes = { { ClassUUID = "wiz", SubClassUUID = "evo", Level = 5 } } },
               Origin = { Origin = "Gale" }, Race = { Race = "human" }, DisplayName = { Name = ts("Gale") } }
entities.CCLevelUpDefinition = { { CCLevelUpDefinition = { Character = gale, LevelUp = { LevelUpData = { Class = "clr", SubClass = "" } } } } }
tick(); dump("Level up Gale 5 -> 6")
expect(BA.Current.build.id == "tempestevoker", "Gale -> Evocation Wizard / Tempest Cleric first")
expect(tempLabel.Text == "* Tempest" and tempGrid.props.Background == RING, "Tempest Domain tile starred + outlined")
expect(lightLabel.Text == "[ForceUpdate]" and lightGrid.props.Background == nil, "Light Domain tile NOT starred by the Light cantrip")
expect(talosLabel.Text == "* Talos", "deity starred at the first Cleric level-up")
expect(lightIcon.props.BorderBrush == ICON and resistIcon.props.BorderBrush == ICON, "planned cantrips outlined")
expect(sacredIcon.props.BorderBrush == CLEAR, "unplanned cantrip not outlined")
expect(uiRoot.kids[8].Text == "Lightning Bolt", "exact labels: Light does not star Lightning Bolt")
entities.CCLevelUpDefinition = nil

-- 10) Feat sub-choice: Shadowheart 7 -> 8 (lightquick: Resilient - Constitution); feat list + passive rows
local resItem, resLabel = tile({ Type = "ls.VMSelectableFeat", Name = "Resilient" })
local alertItem, alertLabel = tile({ Type = "ls.VMSelectableFeat", Name = "Alert" })
local conRow, conTxt, conSrc = passiveRow("Resilient: Constitution")
local wisRow, wisTxt = passiveRow("Resilient: Wisdom")
local strRow2, strName2 = abilityRow("Strength")
setRoot({ assets, resItem, alertItem, conRow, wisRow, strRow2 })
local sh = { EocLevel = { Level = 7 }, Classes = { Classes = { { ClassUUID = "clr", SubClassUUID = "", Level = 7 } } },
             Origin = { Origin = "ShadowHeart" }, Race = { Race = "helf" }, DisplayName = { Name = ts("Shadowheart") } }
BA.Settings.Choices[BA.Norm("ShadowHeart") .. "|" .. BA.Norm("Shadowheart")] = "lightquick"  -- the feat sub-choice lives in lightquick's plan
entities.CCLevelUpDefinition = { { CCLevelUpDefinition = { Character = sh, LevelUp = { LevelUpData = { Class = "clr", SubClass = "" } } } } }
tick(); dump("Level up Shadowheart 7 -> 8")
expect(resLabel.Text == "* Resilient" and alertLabel.Text == "[ForceUpdate]", "feat list: Resilient starred, Alert not")
expect(conTxt.Text == "* Resilient: Constitution" and conSrc.Text == "", "feat sub-choice row starred (name only)")
expect(wisTxt.Text == "[ForceUpdate]", "other feat sub-choice not starred")
expect(strName2.Text == "[ForceUpdate]", "ability rows untouched when the level raises no ability")
entities.CCLevelUpDefinition = nil

-- 11) Ability Improvement rows: Lae'zel 5 -> 6 (bmgiant: +2 STR -> 19). Bracket target, no star; other rows unchanged.
local strRow, strNm = abilityRow("Strength")
local dexRow3, dexNm = abilityRow("Dexterity")
local asiItem, asiLabel = tile({ Type = "ls.VMSelectableFeat", Name = "Ability Improvement" })
setRoot({ assets, asiItem, strRow, dexRow3 })
local lz = { EocLevel = { Level = 5 }, Classes = { Classes = { { ClassUUID = "ftr", SubClassUUID = "", Level = 5 } } },
             Origin = { Origin = "Laezel" }, Race = { Race = "human" }, DisplayName = { Name = ts("Lae'zel") } }
static.ClassDescription.ftr = { Name = "Fighter", DisplayName = ts("Fighter") }
entities.CCLevelUpDefinition = { { CCLevelUpDefinition = { Character = lz, LevelUp = { LevelUpData = { Class = "ftr", SubClass = "" } } } } }
tick(); dump("Level up Lae'zel 5 -> 6")
expect(BA.Current.build.id == "bmgiant", "Lae'zel -> Battle Master (Giantslayer) first")
expect(asiLabel.Text == "* Ability Improvement", "Ability Improvement feat starred")
expect(strNm.Text == "Strength (19, +2)", "ASI row shows the target and the raise, no star: " .. tostring(strNm.Text))
expect(dexNm.Text == "[ForceUpdate]", "ability row the plan does not raise stays unchanged")
entities.CCLevelUpDefinition = nil
tick()
expect(strNm.Text == "Strength", "ASI row restored when the level-up closes")

-- 11b) a bracket text too long for the name column (the row's "-" button covered "Constitution (16, +1") uses the
-- game's short name; the row is still found under it on the next pass and restored to the full name
local conRowB, conNmB = abilityRow("Constitution")
local chaRowB, chaNmB = abilityRow("Charisma")
setRoot({ conRowB, chaRowB })
BA.HL.Apply({}, { CON = { final = 16, bonus = 1 }, CHA = { final = 17, bonus = 2 } })
expect(conNmB.Text == "CON (16, +1)", "long point-buy bracket uses the short name: " .. tostring(conNmB.Text))
expect(chaNmB.Text == "Charisma (17, +2)", "a bracket that fits keeps the full name: " .. tostring(chaNmB.Text))
BA.HL.Apply({}, { CON = { final = 15, bonus = 0 }, CHA = { final = 17, bonus = 2 } })
expect(conNmB.Text == "Constitution (15)", "short-named row found again and updated: " .. tostring(conNmB.Text))
BA.HL.Apply({}, { CON = { final = 16, bonus = 1 } })
BA.HL.Apply({}, nil)
expect(conNmB.Text == "Constitution", "short-named row restored to the full name: " .. tostring(conNmB.Text))

-- 12) Spell swap: Storm Sorcerer 6 -> 7 (stormsorc: Lightning Bolt; replace Witch Bolt with Counterspell)
local wb, cs, lb, mm = spellIcon("Witch Bolt"), spellIcon("Counterspell"), spellIcon("Lightning Bolt"), spellIcon("Magic Missile")
setRoot({ assets, wb, cs, lb, mm, nel("Metamagic: Quickened Spell") })
local tav = { EocLevel = { Level = 6 }, Classes = { Classes = { { ClassUUID = "sor", SubClassUUID = "stm", Level = 4 },
              { ClassUUID = "clr", SubClassUUID = "", Level = 2 } } }, Origin = { Origin = "Generic" }, Race = { Race = "human" },
              DisplayName = { Name = ts("Tav") } }
BA.Settings.Choices["generic|tav"] = "stormsorc"
entities.CCLevelUpDefinition = { { CCLevelUpDefinition = { Character = tav, LevelUp = { LevelUpData = { Class = "sor", SubClass = "" } } } } }
tick(); dump("Level up Storm Sorcerer 6 -> 7")
expect(BA.Current.build.id == "stormsorc", "picked build is remembered")
expect(wb.props.BorderBrush == ICON and cs.props.BorderBrush == ICON, "spell swap: out and in spells outlined")
expect(lb.props.BorderBrush == ICON and mm.props.BorderBrush == CLEAR, "new spell outlined, other spell not")
expect(uiRoot.kids[6].Text == "Metamagic: Quickened Spell", "metamagic from another level not starred")
BA.Settings.Choices["generic|tav"] = nil
-- switching highlighting off restores the outlines
BA.Settings.Highlight = false; BA.HL.Clear()
expect(wb.props.BorderBrush == CLEAR and lb.props.BorderBrush == CLEAR, "outlines restored when highlighting is switched off")
BA.Settings.Highlight = true
entities.CCLevelUpDefinition = nil

-- 12b) Spell icons as the game builds them (CCLib SpellIconTemplate): the Border "border" reads no DataContext;
-- the spell is on the list item's ContentPresenter (ls.VMSpellReference, Spell) and on the elements inside the
-- icon. The view model names the spell by a loca handle (with or without ";1") or by a stats id.
local LOCA = { hb1e55000g0001g = "Bless", hc0e00000g0002g = "Healing Word", hc0e00000g0003g = "Cure Wounds",
               hc0e00000g0004g = "Command", hc0e00000g0005g = "Command: Halt", hc0e00000g0006g = "Counterspell",
               hc0e00000g0007g = "Shield of Faith", hc0e00000g0008g = "Witch Bolt" }
local STATS = {
  Target_Bless = { DisplayName = "hb1e55000g0001g;1" },
  Target_Bless_2_AI = { DisplayName = "hb1e55000g0001g;1" },
  Target_CureWounds = { DisplayName = "hc0e00000g0003g;1" },
  Target_Command_Container = { DisplayName = "hc0e00000g0004g;1" },
  Target_Command_Halt = { DisplayName = "hc0e00000g0005g;2", SpellContainerID = "Target_Command_Container" },
  Target_ShieldOfFaith = { DisplayName = "hc0e00000g0007g;1" },
}
local locaBefore = Ext.Loca.GetTranslatedString
Ext.Loca.GetTranslatedString = function(h) return LOCA[h] or h end -- like the game: an unknown handle comes back as is
Ext.Stats = { Get = function(id) return STATS[id] end }

local function spellVM(fields) fields.Type = "ls.VMCharacterCreationSpell"; return fields end
local function typed(ty, name, kids, dc) local e = pel(ty, name, kids); e.DataContext = dc; return e end
-- SpellIconTemplate; innerDC = what the level TextBlock inside the icon reads (nil: nothing inside reads)
local function iconOf(innerDC)
  return pel("Border", "border", { typed("Grid", "base", { pel("Rectangle"), typed("Grid", "hover"),
    typed("TextBlock", "LevelText", nil, innerDC) }) }, { BorderBrush = CLEAR })
end
local function refOf(vm) return { Type = "ls.VMSpellReference", Spell = vm } end
-- one item of a spell list: availableSpellTemplate (the list to pick from) or selectedSpellTemplate (the picked
-- / prepared row: slot and cross images before the icon, remover / selector images after it)
local function spellItem(vm, selectedRow, innerDC)
  local icon = iconOf(innerDC)
  local inner = typed("ContentPresenter", nil, { typed("Control", nil, { icon }, vm) }, refOf(vm))
  local cc = typed("ContentControl", "icon", { inner })
  local grid = selectedRow
    and typed("Grid", nil, { typed("Image", "slot"), typed("Image", "cross"), cc, typed("Image", "remover"),
                             typed("Image", "selected"), typed("Border", "empty") })
    or typed("Grid", nil, { cc, typed("Image", "selected") })
  return typed("ContentPresenter", nil, { typed("ls.LSButton", nil, { grid }) }, refOf(vm)), icon
end
local function spellList(items) return typed("ItemsControl", nil, { typed("ItemsPresenter", nil, { typed("WrapPanel", nil, items) }) }) end
local ringed = function(icon) return icon.props.BorderBrush == ICON end

-- Prepare Spells, Shadowheart's respec as a Light Cleric at level 1 (Bless, Healing Word, Guiding Bolt and Shield
-- of Faith planned): the Prepared row and the Known Spells list
local blessHandle = spellVM({ Name = "hb1e55000g0001g;1" })
local hwVM = spellVM({ Name = "hc0e00000g0002g" })
local pBless, pBlessIcon = spellItem(blessHandle, true)
local pHw, pHwIcon = spellItem(hwVM, true)
local pEmpty, pEmptyIcon = spellItem(nil, true)
local kBless, kBlessIcon = spellItem(spellVM({ IDString = "Target_Bless" }), false)
local kCure, kCureIcon = spellItem(spellVM({ IDString = "Target_CureWounds" }), false)
local kHw, kHwIcon = spellItem(hwVM, false)
local kSof, kSofIcon = spellItem(spellVM({ IDString = "Target_ShieldOfFaith" }), false)
local kGb, kGbIcon = spellItem(spellVM({ IDString = "Projectile_GuidingBolt" }), false) -- no stats entry: the id's own name
local kCmd, kCmdIcon = spellItem(spellVM({ IDString = "Target_Command_Container" }), false)
setRoot({ assets, spellList({ pBless, pHw, pEmpty }), spellList({ kSof, kBless, kCure, kHw, kCmd, kGb }) })
BA.Settings.Choices[BA.Norm("ShadowHeart") .. "|" .. BA.Norm("Shadowheart")] = "lightcleric"
entities.CCRespecDefinition = { { CCRespecDefinition = { Definition = {
  Name = "Shadowheart", Abilities = { 0, 0, 6, 7, 0, 9, 2 },
  Definition = { Race = "helf", Subrace = "", Origin = "sh" },
  LevelUpData = { Class = "clr", SubClass = "", Upgrades = { AbilityBonuses = {} } } } } } }
tick(); dump("Respec Shadowheart: Prepare Spells")
expect(BA.Current.build.id == "lightcleric" and BA.Current.analysis.highlight[BA.Norm("Bless")], "Light Cleric level 1 plans Bless")
expect(ringed(pBlessIcon), "Prepared row: Bless (loca handle with ;1) ringed")
expect(ringed(pHwIcon), "Prepared row: Healing Word ringed")
expect(not ringed(pEmptyIcon), "Prepared row: empty slot not ringed")
expect(ringed(kBlessIcon), "Known list: Bless (stats id) ringed")
expect(ringed(kHwIcon) and ringed(kSofIcon), "Known list: Healing Word and Shield of Faith ringed")
expect(ringed(kGbIcon), "Known list: Guiding Bolt ringed from its id when the stats cannot be read")
expect(not ringed(kCureIcon) and not ringed(kCmdIcon), "Known list: Cure Wounds and Command not ringed")

-- the extender reads no ContentPresenter (types it cannot read): the elements inside the icon still name the spell
local bareItem, bareIcon = spellItem(nil, false, blessHandle)
local bareCure, bareCureIcon = spellItem(nil, false, spellVM({ IDString = "Target_CureWounds" }))
for _, it in ipairs({ bareItem, bareCure }) do -- no DataContext reads on either ContentPresenter
  it.DataContext = nil; it.kids[1].kids[1].kids[1].kids[1].DataContext = nil
end
setRoot({ assets, spellList({ bareItem, bareCure }) })
tick()
expect(ringed(bareIcon) and not ringed(bareCureIcon), "icon read from inside when the list item reads nothing")

-- spell replacement slots and the class summary's preparable spells: an icon in a bare Control, no list item.
-- A list item before it without an icon of its own must not lend it its spell.
local lonely = typed("ContentPresenter", nil, { typed("TextBlock") }, refOf(hwVM))
local slotIcon = iconOf(nil)
local slot = typed("Control", nil, { slotIcon }, spellVM({ IDString = "Target_CureWounds" }))
local slotIcon2 = iconOf(spellVM({ Name = "hc0e00000g0007g" }))
setRoot({ assets, lonely, slot, typed("Control", nil, { slotIcon2 }) })
tick()
expect(not ringed(slotIcon), "an icon without its own spell does not take the previous list item's spell")
expect(ringed(slotIcon2), "replacement / summary slot icon ringed from the elements inside it")

-- a list rebuilt after a pick: the new item can sit at the address of an element read empty before
local function at(addr, e) return setmetatable(e, { __tostring = function() return addr end }) end
local oldCP = at("cp@1", typed("ContentPresenter", nil, { typed("TextBlock") }, nil))
setRoot({ assets, oldCP })
tick()
local reIcon = iconOf(nil)
local newCP = at("cp@1", typed("ContentPresenter", nil, { typed("ls.LSButton", nil, { reIcon }) }, refOf(blessHandle)))
setRoot({ assets, newCP })
tick()
expect(ringed(reIcon), "a rebuilt list item at a reused address is read on the next pass")

-- spell names: upcast and AI variants, container variants, handles with and without the version
local names = BA.HL.SpellNames
expect(names(spellVM({ IDString = "Target_Bless_2_AI" })).bless, "upcast variant id names its spell")
expect(names(spellVM({ IDString = "Target_Command_Halt" })).command, "container variant names its container")
expect(names(spellVM({ Name = "hb1e55000g0001g;1" })).bless and names(spellVM({ Name = "hb1e55000g0001g" })).bless,
  "loca handle read with and without its version")
expect(names(spellVM({ IDString = "Shout_Unknown_Thing" })).unknownthing == nil, "a variant id without stats names nothing")
entities.CCRespecDefinition = nil
BA.Settings.Choices[BA.Norm("ShadowHeart") .. "|" .. BA.Norm("Shadowheart")] = nil
tick()
expect(not ringed(reIcon), "ring removed when the screen closes")
Ext.Stats = nil
Ext.Loca.GetTranslatedString = locaBefore

-- 13) Origins and the Dark Urge list
local function firstBuilds(origin, cls)
  local ctx = { mode = "Character Creation", origin = origin, classes = {}, pendingClass = cls and { name = cls } or nil }
  local out = {}
  for i, e in ipairs(BA.RankBuilds(ctx, false)) do out[i] = e.build.id end
  return out
end
local o = firstBuilds("Gale"); expect(o[1] == "tempestevoker" and o[2] == "stormsorc", "Gale: tempestevoker, stormsorc")
o = firstBuilds("ShadowHeart"); expect(o[1] == "lightquick" and o[2] == "lightcleric", "Shadowheart: lightquick, lightcleric")
o = firstBuilds("Laezel"); expect(o[1] == "bmgiant" and o[2] == "sorcadin", "Lae'zel: bmgiant, sorcadin")
o = firstBuilds("Karlach"); expect(o[1] == "giants" and o[2] == "throwzerker" and o[3] == "throw_zerk7_thief3", "Karlach: giants, throwzerker, thrower third")
o = firstBuilds("Wyll"); expect(o[1] == "sorlock" and o[2] == "lockadin" and o[3] == "hexsorlock", "Wyll: sorlock, lockadin, hexsorlock third")
o = firstBuilds("DarkUrge", "Wizard")
expect(o[1] == "throw_zerk5_thief4" and o[2] == "throwzerker", "Dark Urge: fixed thrower list first")
local hasEvoker = false
for i = 3, #o do if o[i] == "evoker" or o[i] == "tempestevoker" then hasEvoker = true end end
expect(hasEvoker, "Dark Urge: class matching follows the fixed list (Wizard -> wizard builds)")
local ids = {}
for _, b in ipairs(BA.Builds) do expect(not ids[b.id], "unique build id " .. b.id); ids[b.id] = true end
expect(BA.BuildById.battlemaster ~= nil and BA.BuildById.evoker ~= nil, "battlemaster and evoker stay in the library")

-- 14) planned ability scores stay at or below 20 and every planned raise matches its picks text
for _, b in ipairs(BA.Builds) do
  local s = BA.PlannedScores(b, 12)
  local okMax = true
  for _, ab in ipairs(BA.ABILITIES) do if s[ab] > 20 then okMax = false end end
  expect(okMax, b.id .. " planned scores <= 20")
  for i, lv in ipairs(b.levels) do
    local txt = table.concat(lv.picks, " ")
    local wantsAsi = false
    for _, h in ipairs(lv.hl) do if h == "Ability Improvement" then wantsAsi = true end end
    if wantsAsi then
      expect(lv.asi ~= nil, b.id .. " L" .. i .. " Ability Improvement has its raise")
    end
  end
end


-- 15) window content: the respec screen of Lae'zel (locked race) with one ability off the plan
local function rowsOf(list, style)
  local out = {}
  for _, r in ipairs(list) do if not style or r.style == style then out[#out + 1] = r.text end end
  return out
end
local lz = { mode = "Respec", level = 1, name = "Lae'zel", origin = "Laezel", race = { display = "Githyanki" },
  pendingClass = { name = "Fighter" }, classes = { { name = "Fighter", display = "Fighter", level = 1 } },
  abilities = { STR = 15, DEX = 12, CON = 15, INT = 8, WIS = 14, CHA = 8 }, racial = { STR = 2, CON = 1 } }
local lzEntry = BA.RankBuilds(lz, false)[1]
expect(lzEntry.build.id == "bmgiant", "Lae'zel respec recommends bmgiant")
local out = BA.UI.Outline(lz, lzEntry, BA.Analyse(lz, lzEntry.build))
local skillRows, raceRows = 0, {}
for _, t in ipairs(rowsOf(out.main)) do
  if t:find("^Skills:") then skillRows = skillRows + 1 end
  if t:find("^Race:") then raceRows[#raceRows + 1] = t end
end
expect(skillRows == 1, "one Skills line on the respec screen (class share not repeated): " .. skillRows)
expect(#raceRows == 1 and raceRows[1] == "Race: Githyanki (locked for Lae'zel)", "locked race shown short: " .. tostring(raceRows[1]))
local why = rowsOf(out.main, "note")[1] or ""
expect(why:find("^Best for Lae'zel%. Stays Fighter") ~= nil and not why:find("locked"), "why line: origin name, no repeated race: " .. why)
local warns, oks = rowsOf(out.main, "warn"), rowsOf(out.main, "ok")
expect(#warns == 1 and warns[1]:find("^DEX: 12 %-> set 10") ~= nil, "the one ability off the plan gets its own row: " .. tostring(warns[1]))
expect(#oks == 1 and oks[1] == "Matches the plan: class", "matching choices in one row, locked race left out: " .. tostring(oks[1]))
local hasNote = false
for _, t in ipairs(rowsOf(out.about)) do if t:find("already a Fighter") then hasNote = true end end
expect(hasNote, "build note moves to the folded About section")
lz.abilities.DEX = 10
out = BA.UI.Outline(lz, lzEntry, BA.Analyse(lz, lzEntry.build))
oks = rowsOf(out.main, "ok")
expect(#oks == 1 and oks[1] == "All match the plan: class, abilities" and #rowsOf(out.main, "warn") == 0, "all choices fine: one green row: " .. tostring(oks[1]))
lz.pendingClass = { name = "Wizard" }
out = BA.UI.Outline(lz, lzEntry, BA.Analyse(lz, lzEntry.build))
local bad = rowsOf(out.main, "bad")
expect(#bad == 1 and bad[1]:find("take Fighter") ~= nil, "wrong class gets a red row: " .. tostring(bad[1]))
local lv = { mode = "Level Up", level = 5, name = "Lae'zel", origin = "Laezel", race = { display = "Githyanki" },
  pendingClass = { name = "Fighter" }, classes = { { name = "Fighter", display = "Fighter", level = 4 } } }
out = BA.UI.Outline(lv, lzEntry, BA.Analyse(lv, lzEntry.build))
local items = rowsOf(out.main, "item")
expect(items[1] == "Level 5: Fighter" and #items == 1, "level-up: only this level's class and picks: " .. tostring(items[1]))

-- 16) placement: beside the game's left panel in the menus, the old spot outside, the player's move kept
local pos1, size1 = BA.UI.DockRect(2560, 1600)
local s16 = 1600 / 2160
expect(math.abs(pos1[2] - 148 * s16) < 0.5 and math.abs(pos1[2] + size1[2] - 1852 * s16) < 0.5,
  string.format("dock top / bottom = the left panel's frame: %.0f-%.0f", pos1[2], pos1[2] + size1[2]))
expect(math.abs(pos1[1] - 1530 * s16) < 0.5 and pos1[1] + size1[1] <= 2560 - 790 * s16 + 0.5,
  string.format("dock left of the summary panel: x %.0f-%.0f", pos1[1], pos1[1] + size1[1]))
local pos2, size2 = BA.UI.DockRect(1920, 1080)
expect(math.abs(pos2[2] - 74) < 0.5 and math.abs(size2[2] - 852) < 0.5, "dock scales with the screen height (1080p)")
local w = BA.UI.window
local placed = {}
rawset(w, "SetPos", function(_, p) placed[#placed + 1] = { pos = p } end)
rawset(w, "SetSize", function(_, sz) placed[#placed].size = sz end)
Ext.IMGUI.GetViewportSize = function() return { 2560, 1600 } end
BA.UI.placement, BA.UI.userPlaced = nil, nil
entities.ClientControl = nil
entities.CCRespecDefinition = { { CCRespecDefinition = { Definition = {
  Name = "Shadowheart", Abilities = { 0, 10, 13, 14, 10, 17, 8 },
  Definition = { Race = "helf", Subrace = "", Origin = "sh" },
  LevelUpData = { Class = "clr", SubClass = "", Upgrades = { AbilityBonuses = {} } } } } } }
tick(); log = {}
local last = placed[#placed]
expect(w.Open == true and last and math.abs(last.pos[1] - pos1[1]) < 0.5 and math.abs(last.size[2] - size1[2]) < 0.5,
  "respec auto-open docks the window beside the left panel")
rawset(w, "LastPosition", { last.pos[1], last.pos[2] }); rawset(w, "LastSize", { last.size[1], last.size[2] })
tick(); log = {}
local n = #placed
rawset(w, "LastPosition", { 300, 200 }) -- the player drags the window
tick(); log = {}
expect(BA.UI.userPlaced == true, "a move by the player is noticed")
BA.UI.placement.kind = "free"; BA.UI.Place(true)
expect(#placed == n, "a moved window is never put back")
rawset(w, "LastSize", { 600, 900 })
tick(); log = {}
expect(BA.UI.widthPx == 600, "text re-wraps to the player's width")
entities.CCRespecDefinition = nil
tick(); log = {}
Ext.IMGUI.GetViewportSize = nil

-- 7) every build has 12 levels, valid abilities (27 point buy) and classes
local cost = { [8] = 0, [9] = 1, [10] = 2, [11] = 3, [12] = 4, [13] = 5, [14] = 7, [15] = 9 }
for _, b in ipairs(BA.Builds) do
  local pts = 0
  for _, a in ipairs(BA.ABILITIES) do pts = pts + (cost[b.base[a]] or 99) end
  expect(#b.levels == 12 and pts == 27 and b.levels[1].cls == b.start, b.id .. " (12 levels, 27 pts=" .. pts .. ", starts " .. b.start .. ")")
  for _, lv in ipairs(b.levels) do
    local known = false
    for _, c in ipairs(b.classes) do if c == lv.cls then known = true end end
    if not known then expect(false, b.id .. " level uses undeclared class " .. lv.cls) end
  end
end
for k, o in pairs(BA.Origins) do for _, id in ipairs(o.builds) do expect(BA.BuildById[id] ~= nil, "origin " .. k .. " -> " .. id) end end

print(fails == 0 and "\nALL TESTS PASSED" or ("\n" .. fails .. " FAILURES"))
return fails
