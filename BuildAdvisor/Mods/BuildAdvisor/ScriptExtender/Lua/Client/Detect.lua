-- Reads the character currently being created / respecced / levelled up (or the selected party member)
-- from ECS components. Everything is wrapped in pcall: component layouts change between game patches.

BA = BA or {}

local NULL_GUID = "00000000-0000-0000-0000-000000000000"
local ABILITIES = { "STR", "DEX", "CON", "INT", "WIS", "CHA" }
local ABILITY_IDS = { Strength = "STR", Dexterity = "DEX", Constitution = "CON", Intelligence = "INT", Wisdom = "WIS", Charisma = "CHA" }
BA.ABILITIES = ABILITIES

function BA.Norm(s)
  local r = tostring(s or ""):lower():gsub("[^%w]", "")
  return r
end

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end

local function validGuid(g)
  return g ~= nil and g ~= "" and g ~= NULL_GUID
end

local function translated(ts)
  if not ts then return nil end
  local s = try(function() return ts:Get() end)
  if (not s or s == "") then s = try(function() return Ext.Loca.GetTranslatedString(ts.Handle.Handle) end) end
  if s == "" then return nil end
  return s
end

-- Returns resource, display name, internal name
local cache = {}
local function resource(guid, kind)
  if not validGuid(guid) then return nil end
  local key = kind .. guid
  if cache[key] == nil then
    local res = try(Ext.StaticData.Get, guid, kind)
    if res then
      cache[key] = { res = res, display = translated(res.DisplayName), name = try(function() return res.Name end) }
    else
      cache[key] = false
    end
  end
  return cache[key] or nil
end

-- Base class name (English internal name, e.g. "Paladin") + subclass display name
local function classInfo(classGuid, subGuid)
  local c = resource(classGuid, "ClassDescription")
  if not c then return nil end
  local info = { name = c.name, display = c.display or c.name, sub = nil }
  -- If we were handed a subclass, walk to its parent
  local parent = try(function() return c.res.ParentGuid end)
  if validGuid(parent) then
    local p = resource(parent, "ClassDescription")
    if p then
      info.sub = c.display or c.name
      info.name, info.display = p.name, p.display or p.name
    end
  end
  local s = resource(subGuid, "ClassDescription")
  if s then info.sub = s.display or s.name end
  return info
end

-- pointBuy: character creation / respec definitions store the points bought on top of the base 8
-- (STR 15 reads back as 7). A real score is never below 8 there, so all-below-8 means offsets.
local function abilityTable(arr, pointBuy)
  if not arr then return nil end
  local n = try(function() return #arr end) or 0
  if n < 6 then return nil end
  local off = (n >= 7) and 1 or 0 -- index 1 is "None" in the 7-entry layout
  local t, max = {}, 0
  for i, a in ipairs(ABILITIES) do
    t[a] = try(function() return arr[i + off] end)
    if type(t[a]) == "number" and t[a] > max then max = t[a] end
  end
  if pointBuy and max < 8 then
    for _, a in ipairs(ABILITIES) do if type(t[a]) == "number" then t[a] = t[a] + 8 end end
  end
  return t
end

-- Racial +2/+1 choices from a LevelUpData (character creation only)
local function racialBonuses(levelUpData)
  local out = {}
  try(function()
    for _, sel in ipairs(levelUpData.Upgrades.AbilityBonuses) do
      for i, ab in ipairs(sel.Bonuses) do
        local short = ABILITY_IDS[tostring(ab)]
        local amt = sel.BonusAmounts and sel.BonusAmounts[i]
        if short and amt then out[short] = (out[short] or 0) + amt end
      end
    end
  end)
  return out
end

local function originName(originGuidOrName)
  if not originGuidOrName then return nil end
  local r = resource(originGuidOrName, "Origin")
  if r then return r.name end
  return tostring(originGuidOrName) -- Origin component already stores the name
end

local function raceInfo(raceGuid, subraceGuid)
  local r = resource(validGuid(subraceGuid) and subraceGuid or raceGuid, "Race")
  local base = resource(raceGuid, "Race")
  if not r and not base then return nil end
  return { display = (r and r.display) or (base and base.display), name = (r and r.name) or (base and base.name),
           baseDisplay = base and base.display }
end

local function displayName(e)
  return try(function() return translated(e.DisplayName.Name) end)
      or try(function() return e.DisplayName.NameKey and translated(e.DisplayName.NameKey) end)
end

local function classesOf(e)
  local list = {}
  try(function()
    for _, c in ipairs(e.Classes.Classes) do
      local ci = classInfo(c.ClassUUID, c.SubClassUUID)
      if ci then ci.level = c.Level; table.insert(list, ci) end
    end
  end)
  return list
end

local function firstEntity(component)
  local list = try(Ext.Entity.GetAllEntitiesWithComponent, component)
  if list and #list > 0 then return list[1] end
  return nil
end

-- Character-creation style definition (new game or Withers respec)
local function fromCharacterDefinition(def, mode)
  local ctx = { mode = mode, level = 1, classes = {} }
  local base = def.Definition
  ctx.name = try(function() return def.Name end)
  ctx.race = raceInfo(try(function() return base.Race end), try(function() return base.Subrace end))
  ctx.origin = originName(try(function() return base.Origin end))
  local lud = try(function() return def.LevelUpData end)
  if lud then
    local ci = classInfo(lud.Class, lud.SubClass)
    if ci then ci.level = 1; ctx.classes = { ci }; ctx.pendingClass = ci end
    ctx.racial = racialBonuses(lud)
  end
  ctx.abilities = abilityTable(try(function() return def.Abilities end), true)
  return ctx
end

function BA.Detect()
  -- 1) Level up
  local e = firstEntity("CCLevelUpDefinition")
  if e then
    local ctx = try(function()
      local lu = e.CCLevelUpDefinition
      local ch = lu.Character
      local c = { mode = "Level Up", classes = ch and classesOf(ch) or {} }
      c.level = ((ch and try(function() return ch.EocLevel.Level end)) or 0) + 1
      c.name = ch and displayName(ch)
      c.origin = ch and originName(try(function() return ch.Origin.Origin end))
      c.race = ch and raceInfo(try(function() return ch.Race.Race end))
      local lud = lu.LevelUp.LevelUpData
      c.pendingClass = classInfo(lud.Class, lud.SubClass)
      return c
    end)
    if ctx then return ctx end
  end

  -- 2) Withers respec (character-creation screen at level 1)
  for _, comp in ipairs({ "CCRespecDefinition", "CCFullRespecDefinition" }) do
    e = firstEntity(comp)
    if e then
      local ctx = try(function()
        local d = e[comp].Definition
        if comp == "CCRespecDefinition" then return fromCharacterDefinition(d, "Respec") end
        local c = { mode = "Respec", level = 1, classes = {} }
        c.name = d.Name
        c.race = raceInfo(d.Definition.Race, d.Definition.Subrace)
        c.origin = originName(d.Definition.Origin)
        local first = d.LevelUpData and d.LevelUpData[1]
        local ci = first and classInfo(first.Class, first.SubClass)
        if ci then ci.level = 1; c.classes = { ci }; c.pendingClass = ci end
        c.abilities = abilityTable(d.Abilities, true)
        return c
      end)
      if ctx then return ctx end
    end
  end

  -- 3) New game character creation
  e = firstEntity("CCCharacterDefinition")
  if e then
    local ctx = try(function() return fromCharacterDefinition(e.CCCharacterDefinition.Definition, "Character Creation") end)
    if ctx then return ctx end
  end

  -- 4) Not in a creation screen: the party member this client controls
  local controlled = try(Ext.Entity.GetAllEntitiesWithComponent, "ClientControl") or {}
  for _, ch in ipairs(controlled) do
    local hasClasses = try(function() return ch.Classes ~= nil end)
    if hasClasses then
      local ctx = { mode = "Party", classes = classesOf(ch) }
      ctx.level = try(function() return ch.EocLevel.Level end) or 1
      ctx.name = displayName(ch)
      ctx.origin = originName(try(function() return ch.Origin.Origin end))
      ctx.race = raceInfo(try(function() return ch.Race.Race end))
      ctx.abilities = abilityTable(try(function() return ch.Stats.Abilities end))
      ctx.abilitiesAreFinal = true
      return ctx
    end
  end
  return nil
end

-- Mode in which the in-menu highlighter should run
function BA.IsCreationMode(ctx)
  return ctx ~= nil and ctx.mode ~= "Party"
end
