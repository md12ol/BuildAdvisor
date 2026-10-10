-- Offline test: the in-menu highlighter touches the game's UI tree only from Ext.UI.Defer.
-- Noesis renders in parallel with Lua, so before Script Extender v33 (no Ext.UI.Defer) the mod must leave the tree
-- alone unless the player opts in (UnsafeUiOnOldSE), and with Ext.UI.Defer every touch must happen inside the
-- deferred callback. Run by tools/run_tests.py, once per scenario:
--   ROOT, DEFER (bool), UNSAFE (bool), PATCHES ({ [file name] = { {old, new}, ... } }), MENU (the x:Name of a
--   game widget that hides the window, e.g. "GameMenu" or the message box "Dialog_box", or nil: open during the
--   first ticks, then closed) -> result table
local ROOT, DEFER, UNSAFE, PATCHES, MENU = ...
local LUA = ROOT .. "/BuildAdvisor/Mods/BuildAdvisor/ScriptExtender/Lua/"

local R = { touches = 0, outside = 0, labels = 0, prints = {}, renders = 0 }
local inDefer = false
local function touch(label)
  R.touches = R.touches + 1
  if not inDefer then R.outside = R.outside + 1 end
  if label then R.labels = R.labels + 1 end
end

-- UI tree: every field read is counted; the labels are names a Paladin start recommends
local function el(text, kids, ty, name, props)
  local d = { Text = text, kids = kids or {}, Type = ty or "TextBlock", Name = name, props = props or {} }
  return setmetatable({}, {
    __index = function(_, k)
      touch(text ~= nil)
      if k == "Text" then return d.Text end
      if k == "Type" then return d.Type end
      if k == "Name" then return d.Name end
      if k == "GetProperty" then return function(_, p) touch(text ~= nil); return d.props[p] end end
      if k == "VisualChildrenCount" then return #d.kids end
      if k == "VisualChild" then return function(_, i) touch(text ~= nil); return d.kids[i] end end
      if k == "GetProperty" or k == "SetProperty" or k == "Resource" then return function() touch(text ~= nil) end end
      return nil
    end,
    __newindex = function(_, k, v) touch(text ~= nil); if k == "Text" then d.Text = v end end,
  })
end
local uiKids = { el("Half-Orc"), el("Human"), el(nil, { el("Paladin"), el("Sorcerer") }), el("Athletics") }
local uiRoot = el(nil, uiKids)
if MENU then uiKids[#uiKids + 1] = el(nil, { el(nil, {}, "ls.UIWidget", MENU, { Visibility = "Visible" }) }) end

-- IMGUI window: any Add* call returns another node; the window counts renders through AddText
local function node()
  return setmetatable({ children = {} }, { __index = function(_, k)
    if k:sub(1, 3) == "Add" then
      return function() if k == "AddText" then R.renders = R.renders + 1 end return node() end
    end
    return function() end
  end })
end

local function ts(s) return { Get = function() return s end, Handle = { Handle = s } } end
local static = {
  ClassDescription = { pal = { Name = "Paladin", DisplayName = ts("Paladin") },
                       sor = { Name = "Sorcerer", DisplayName = ts("Sorcerer") } },
  Race = { human = { Name = "Human", DisplayName = ts("Human") } },
  Origin = { tav = { Name = "Generic" } },
}
local entities = { CCCharacterDefinition = { {
  CCCharacterDefinition = { Definition = {
    Name = "Tav", Abilities = { 0, 10, 10, 10, 10, 10, 10 },
    Definition = { Race = "human", Subrace = "", Origin = "tav" },
    LevelUpData = { Class = "pal", SubClass = "", Upgrades = { AbilityBonuses = {} } },
  } } } } }

local subs = { Tick = {}, KeyInput = {}, SessionLoaded = {}, ResetCompleted = {} }
local function event(name) return { Subscribe = function(_, f) table.insert(subs[name], f) end } end
local now, deferred = 0, {}
local function out(s) R.prints[#R.prints + 1] = tostring(s) end

local function loadMod(rel)
  local f = assert(io.open(LUA .. rel, "rb"))
  local src = f:read("a")
  f:close()
  local name = rel:match("([^/]+)$")
  for _, p in ipairs((PATCHES or {})[name] or {}) do
    local a, b = string.find(src, p[1], 1, true)
    if not a then error("patch target not found in " .. name .. ": " .. p[1]) end
    src = src:sub(1, a - 1) .. p[2] .. src:sub(b + 1)
  end
  return assert(load(src, "@" .. rel))()
end

Ext = {
  Require = function(p) return loadMod(p) end,
  StaticData = { Get = function(g, kind) return static[kind] and static[kind][g] end },
  Loca = { GetTranslatedString = function(h) return h end },
  Entity = { GetAllEntitiesWithComponent = function(c) return entities[c] or {} end },
  IMGUI = { NewWindow = function() return node() end },
  UI = { GetRoot = function() touch(); return uiRoot end },
  IO = { LoadFile = function(p)
           if UNSAFE and p == "BuildAdvisor_settings.json" then return "unsafe" end
         end, SaveFile = function() return true end },
  Json = { Parse = function(s) if s == "unsafe" then return { UnsafeUiOnOldSE = true } end return {} end,
           Stringify = function() return "{}" end },
  Utils = { MonotonicTime = function() return now end, Print = out, PrintWarning = out, PrintError = out },
  Events = { Tick = event("Tick"), KeyInput = event("KeyInput"), SessionLoaded = event("SessionLoaded"),
             ResetCompleted = event("ResetCompleted") },
  RegisterConsoleCommand = function() end,
}
if DEFER then Ext.UI.Defer = function(f) deferred[#deferred + 1] = f end end
_D = out

loadMod("BootstrapClient.lua")
for _, f in ipairs(subs.SessionLoaded) do f() end
R.ticks = 0
local function ticks(n)
  for _ = 1, n do
    now = now + 1100
    for _, f in ipairs(subs.Tick) do f() end
    local q = deferred
    deferred = {}
    inDefer = true
    for _, f in ipairs(q) do f() end
    inDefer = false
    R.ticks = R.ticks + 1
  end
end
ticks(8)
-- the pause menu: the window is closed under it; the hotkey there only changes what happens after it
R.openBefore = rawget(BA.UI.window, "Open") == true or BA.UI.reopen == true
R.hiddenInMenu = BA.UI.menuHidden == true and rawget(BA.UI.window, "Open") ~= true
if MENU then
  local menu = uiKids[#uiKids]
  uiKids[#uiKids] = nil
  ticks(2)
  R.reopened = rawget(BA.UI.window, "Open") == true
  uiKids[#uiKids + 1] = menu
  ticks(2)
  BA.UI.Toggle()
  R.openAfterKeys = rawget(BA.UI.window, "Open") == true
end
-- leaving the screen: the restore pass must also wait for Ext.UI.Defer
entities.CCCharacterDefinition = nil
for _ = 1, 2 do
  now = now + 1100
  for _, f in ipairs(subs.Tick) do f() end
  local q = deferred
  deferred = {}
  inDefer = true
  for _, f in ipairs(q) do f() end
  inDefer = false
  R.ticks = R.ticks + 1
end
R.inMode = BA.Current ~= nil
return R
