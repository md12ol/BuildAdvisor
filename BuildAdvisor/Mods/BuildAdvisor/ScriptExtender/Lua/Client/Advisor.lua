-- Pure logic: pick builds for a character and work out what to choose right now.

BA = BA or {}

local function classCounts(classes)
  local t = {}
  for _, c in ipairs(classes or {}) do t[c.name] = (t[c.name] or 0) + (c.level or 0) end
  return t
end

local function planCounts(build, upto)
  local t = {}
  for i = 1, math.min(upto, #build.levels) do
    local cls = build.levels[i].cls
    t[cls] = (t[cls] or 0) + 1
  end
  return t
end

function BA.OriginKey(ctx)
  return ctx and BA.Norm(ctx.origin) or ""
end

function BA.OriginInfo(ctx)
  return BA.Origins[BA.OriginKey(ctx)]
end

-- The class that was (or is being) taken at level 1
local function startClass(ctx)
  if ctx.mode ~= "Level Up" and ctx.pendingClass then return ctx.pendingClass.name end
  local first = ctx.classes and ctx.classes[1]
  return first and first.name or (ctx.pendingClass and ctx.pendingClass.name)
end

-- Returns ordered list of { build = b, reason = "..." }
function BA.RankBuilds(ctx, showAll)
  local out, seen = {}, {}
  local function add(b, reason)
    if b and not seen[b.id] then seen[b.id] = true; table.insert(out, { build = b, reason = reason }) end
  end

  local origin = BA.OriginInfo(ctx)
  if origin then
    for _, id in ipairs(origin.builds) do add(BA.BuildById[id], "Best for " .. tostring(ctx.origin)) end
  end

  local start = ctx and startClass(ctx)
  local have = classCounts(ctx and ctx.classes)
  if start then
    for _, b in ipairs(BA.Builds) do
      if b.start == start then add(b, "Starts as " .. start) end
    end
    for _, b in ipairs(BA.Builds) do
      for _, c in ipairs(b.classes) do
        if c == start then add(b, "Uses " .. start) end
      end
    end
  end
  -- multiclassed characters: also builds that contain every class they already have
  for _, b in ipairs(BA.Builds) do
    local ok = next(have) ~= nil
    for cls in pairs(have) do
      local found = false
      for _, c in ipairs(b.classes) do if c == cls then found = true end end
      ok = ok and found
    end
    if ok then add(b, "Matches your classes") end
  end
  if showAll or #out == 0 then
    for _, b in ipairs(BA.Builds) do add(b, "Tier " .. b.tier) end
  end
  return out
end

-- Everything the UI needs for the current step
function BA.Analyse(ctx, build)
  local a = { checks = {}, warnings = {} }
  local n = math.max(1, math.min(ctx.level or 1, #build.levels))
  a.level = n
  a.step = build.levels[n]
  a.nextStep = (ctx.mode == "Party") and build.levels[n + 1] or nil

  -- Race (only relevant during creation / respec; origins are locked)
  if ctx.race and (ctx.mode == "Character Creation" or ctx.mode == "Respec") then
    local rn = BA.Norm(ctx.race.display)
    local best, alt = BA.Norm(build.races[1]), false
    for i = 2, #build.races do if rn == BA.Norm(build.races[i]) then alt = true end end
    local locked = BA.OriginInfo(ctx) and BA.OriginKey(ctx) ~= "generic" and BA.OriginKey(ctx) ~= "darkurge"
    if locked then
      table.insert(a.checks, { ok = true, text = "Race: " .. tostring(ctx.race.display) .. " (locked for this origin)" })
    elseif rn == best or rn:find(best, 1, true) then
      table.insert(a.checks, { ok = true, text = "Race: " .. ctx.race.display .. " - best pick" })
    elseif alt then
      table.insert(a.checks, { ok = true, text = "Race: " .. ctx.race.display .. " - good alternative (best: " .. build.races[1] .. ")" })
    else
      table.insert(a.checks, { ok = false, text = "Race: " .. tostring(ctx.race.display) .. " -> pick " .. table.concat(build.races, " / ") })
    end
  end

  -- Class for this level
  local want = a.step.cls
  if ctx.mode == "Party" then
    want = a.nextStep and a.nextStep.cls
  end
  if ctx.pendingClass and ctx.mode ~= "Party" then
    local ok = ctx.pendingClass.name == want
    table.insert(a.checks, { ok = ok, text = ok and ("Class this level: " .. want) or
      ("Class this level: " .. tostring(ctx.pendingClass.name) .. " -> take " .. want) })
  end

  -- Class split so far vs plan
  local have = classCounts(ctx.classes)
  local expect = planCounts(build, (ctx.mode == "Level Up") and n - 1 or n)
  if ctx.mode ~= "Character Creation" and ctx.mode ~= "Respec" then
    local diff = {}
    for cls, lv in pairs(expect) do if (have[cls] or 0) ~= lv then table.insert(diff, cls .. " " .. (have[cls] or 0) .. "/" .. lv) end end
    for cls, lv in pairs(have) do if not expect[cls] then table.insert(diff, cls .. " " .. lv .. "/0") end end
    if #diff > 0 then
      table.insert(a.warnings, "Class levels differ from the plan (" .. table.concat(diff, ", ") ..
        "). Keep following the plan or respec with Withers (100 gold) to line up.")
    end
  end

  -- Abilities
  if ctx.mode == "Character Creation" or ctx.mode == "Respec" then
    -- per-ability plan for the game's own point-buy rows: final score after the racial bonus, and that bonus
    a.skillPlan = build.skills
    a.abilityPlan = {}
    for _, ab in ipairs(BA.ABILITIES) do
      if build.base[ab] then
        local bonus = (ab == build.plus2 and 2) or (ab == build.plus1 and 1) or 0
        a.abilityPlan[ab] = { final = build.base[ab] + bonus, bonus = bonus }
      end
    end
  elseif ctx.mode == "Level Up" and a.step and a.step.asi then
    -- Ability Improvement / feat ability rows: the planned score after this level's raise, and the raise
    local scores = BA.PlannedScores(build, n)
    a.abilityPlan = {}
    for ab, amount in pairs(a.step.asi) do a.abilityPlan[ab] = { final = scores[ab], bonus = amount } end
  end
  if ctx.abilities then
    for _, ab in ipairs(BA.ABILITIES) do
      local target = build.base[ab]
      local bonus = (ab == build.plus2 and 2) or (ab == build.plus1 and 1) or 0
      local cur = ctx.abilities[ab]
      if cur and target then
        if ctx.abilitiesAreFinal then
          table.insert(a.checks, { ok = cur >= target + bonus, text = string.format("%s %d (plan >= %d)", ab, cur, target + bonus), minor = true })
        else
          local curBonus = (ctx.racial and ctx.racial[ab]) or 0
          local okBase = cur == target or cur + curBonus == target + bonus
          table.insert(a.checks, { ok = okBase, minor = true,
            text = string.format("%s: %d -> set %d%s", ab, cur, target, bonus > 0 and (" (+" .. bonus .. " racial)") or "") })
        end
      end
    end
  end

  -- Strings to highlight inside the game's own menus
  local hl = {}
  local function addHl(s) if s and s ~= "" then hl[BA.Norm(s)] = s end end
  local step = (ctx.mode == "Party") and a.nextStep or a.step
  if step then
    for _, s in ipairs(step.hl) do addHl(s) end
    addHl(step.cls)
    if step.swap then addHl(step.swap.out); addHl(step.swap.into) end
  end
  if ctx.mode == "Character Creation" or ctx.mode == "Respec" then
    addHl(build.races[1])
    addHl(build.start)
    addHl(build.bg)
    addHl(build.deity)
    for _, s in ipairs(build.skills or {}) do addHl(s) end
    for _, s in ipairs(build.raceHl or {}) do addHl(s) end
  elseif step and step.cls == "Cleric" and build.deity then
    addHl(build.deity) -- a first Cleric level taken at level-up also asks for a deity
  end
  a.highlight = hl
  return a
end

-- Planned ability scores after character level n: point buy + racial bonus + every planned raise up to n
function BA.PlannedScores(build, n)
  local s = {}
  for _, ab in ipairs(BA.ABILITIES) do
    s[ab] = (build.base[ab] or 8) + ((ab == build.plus2 and 2) or (ab == build.plus1 and 1) or 0)
  end
  for i = 1, math.min(n, #build.levels) do
    for ab, amount in pairs(build.levels[i].asi or {}) do s[ab] = s[ab] + amount end
  end
  return s
end
