-- Marks recommended options directly in the game's own (Noesis) character creation / respec / level-up menus:
-- walks the visual tree and prefixes matching labels with a marker, outlines matching tiles and spell icons with
-- the rainbow "Prism" ring, and adds the target score to point-buy and ability-improvement rows. Everything it
-- changes is restored when the recommendation changes, highlighting is switched off or the screen closes.
--
-- Two kinds of labels exist in the game UI:
--  * plain TextBlocks whose Text is the visible string (headers, feat / passive rows, summary panels)
--  * list items (class / race / subclass / background / deity grids, ...) whose TextBlocks are bound to a view
--    model; their Text reads back as nil or "[ForceUpdate]" and the real name lives on the item's DataContext.
-- Outlines (no colour brush can be created from Lua, so the brushes come from our hidden resource widget):
--  * tiles (race, subrace, class, subclass, background, deity): the Grid that holds the tile picture and the
--    game's "frame" selector image gets our ring as its Background (drawn around the picture; the game's own
--    hover / selection frame keeps working on top of it)
--  * spell and cantrip icons: the icon's 4-pixel "border" Border gets our ring brush as BorderBrush
-- Feats, fighting styles, manoeuvres, invocations, metamagic and other passive choices are text rows in the game
-- (check box + name), so they get the star only.

BA = BA or {}
BA.HL = { active = false }
-- ContentPresenters whose DataContext read came back empty (the extender cannot read some types, e.g.
-- ls.LocaString, and prints an error each time). They are skipped, but retried every RETRY_PASSES passes
-- because rows on a freshly opened screen are briefly empty too. Keyed by tostring(element), which is its
-- address: a list rebuilt after a pick reuses addresses, so the entry holds the element's shape too and a
-- different element at the same address is read at once.
local unreadableDC, pass = {}, 0
local RETRY_PASSES = 10

local MARK = "* "
local NODE_BUDGET = 30000
local MATCH_FIELDS = { "DisplayName", "Name", "Title", "IDString" }
local BOUND_PLACEHOLDER = "[ForceUpdate]" -- what a bound TextBlock's Text reads back as
local ASSET_WIDGET = "BuildAdvisorRes" -- leak-ok: x:Name of our hidden resource widget, never shown

-- Getters are defined once so the walk does not allocate a closure per node.
local function getType(e) return e.Type end
local function getName(e) return e.Name end
local function getText(e) return e.Text end
local function setText(e, t) e.Text = t end
local function getCount(e) return e.VisualChildrenCount end
local function getChild(e, i) return e:VisualChild(i) end
local function getDC(e) return e.DataContext end
local function getField(o, k) return o[k] end
local function getProp(o, k) return o:GetProperty(k) end
local function setProp(o, k, v) o:SetProperty(k, v) end

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end

-- Every read or write of the Noesis tree goes through BA.HL.Run. Noesis renders in parallel with Lua, so a walk
-- from the game tick can reach an element the UI has just freed and crash the game. Ext.UI.Defer (Script Extender
-- v33+) runs the code at the start of the next UI update, where that cannot happen. Older Script Extender has no
-- safe moment, so the code is skipped there unless the player opts in with the setting UnsafeUiOnOldSE.
-- Returns true when fn was run or queued.
local warnedOldSE = false
function BA.HL.Run(fn)
  local defer = try(function() return Ext.UI.Defer end)
  if defer then
    defer(function() pcall(fn) end)
    return true
  end
  if BA.Settings and BA.Settings.UnsafeUiOnOldSE == true then
    pcall(fn)
    return true
  end
  if not warnedOldSE then
    warnedOldSE = true
    Ext.Utils.Print("[Build Advisor] the stars and outlines in the game's menus need Script Extender v33 or newer;"
      .. " this Script Extender is older, so they are off. The advisor window still works.")
  end
  return false
end

-- The game's pause menu (Esc) and the pages it opens (options, save, load) are widgets on the UI's Pause layer,
-- named by the x:Name of their XAML page (GameMenu.xaml: "GameMenu"). The game's message boxes (the respec "lose
-- progress?" confirmation, the new game's tutorial question) are the widget of MessageBox.xaml, "Dialog_box", and
-- MessageBox_c.xaml on a controller. Script Extender windows draw over every game widget, so the advisor window
-- hides while one of them is shown. Run through BA.HL.Run only: sets BA.HL.menuOpen. The widgets sit a few levels
-- below ContentRoot; their insides are not walked.
BA.HL.PAUSE_WIDGETS = { GameMenu = true, GameOptions = true, InterfaceOptions = true, AccessibilityOptions = true,
                        ConnectivityMenu = true, LoadGame = true, SaveGame = true,
                        Dialog_box = true, MessageBox_c = true }
function BA.HL.CheckMenu()
  local root = try(Ext.UI.GetRoot)
  if not root then return end
  local content = try(function() return root:Find("ContentRoot") end) or root
  local open, budget = false, 400
  local function go(e, d)
    if open or budget <= 0 then return end
    budget = budget - 1
    if tostring(try(getType, e)):find("UIWidget", 1, true) then
      -- an unreadable Visibility counts as shown: the widget only exists while its state is on the stack
      local v = try(getProp, e, "Visibility")
      if BA.HL.PAUSE_WIDGETS[try(getName, e) or ""] and (v == nil or tostring(v) == "Visible") then open = true end
      return
    end
    if d >= 4 then return end
    for i = 1, (try(getCount, e) or 0) do
      local c = try(getChild, e, i)
      if c then go(c, d + 1) end
    end
  end
  go(content, 0)
  BA.HL.menuOpen = open
end

local function stripMark(t)
  if t:sub(1, #MARK) == MARK then return t:sub(#MARK + 1), true end
  return t, false
end

-- Exact match on the normalized label (lower case, letters and digits only). The plan's labels are the game's
-- own English menu texts, so no fuzzy matching is needed (and "Shield" must not star "Shield of Faith").
local function matches(norm, wanted) return wanted[norm] ~= nil end

local function isTextType(ty) return ty == nil or ty == "TextBlock" or ty:find("TextBlock", 1, true) ~= nil end
local function isItemType(ty)
  return ty ~= nil and (ty:find("Item", 1, true) or ty:find("RadioButton", 1, true) or ty:find("CheckBox", 1, true)) ~= nil
end

-- A view-model field: the plain field read (works for the creation view models); the Noesis property only when
-- the plain read itself fails, so a missing field costs one call per pass
local function vmField(dc, k)
  local ok, v = pcall(getField, dc, k)
  if ok then return v end
  return try(getProp, dc, k)
end

-- Loca handles come with or without their version suffix ("h5e48...;1"); the lookup takes the bare handle
local function locaText(h)
  local t = try(Ext.Loca.GetTranslatedString, (h:gsub(";.*$", "")))
  if type(t) == "string" and t ~= "" and t ~= h then return t end
  return nil
end
local function isHandle(v) return v:match("^h%x+g%x+g") ~= nil end
local function isStatId(v) return v:find("_", 1, true) ~= nil and not v:find(" ", 1, true) end

-- Stats entry of an id: display name and container ("Target_Command_Halt" -> "Target_Command_Container").
-- A failed read is not cached: stats can be missing early.
local statCache = {}
local function statEntry(id)
  if type(id) ~= "string" or id == "" then return nil end
  local e = statCache[id]
  if e then return e end
  local st = Ext.Stats and try(Ext.Stats.Get, id)
  if not st then return nil end
  local h = try(getField, st, "DisplayName")
  e = { name = type(h) == "string" and locaText(h) or nil, container = try(getField, st, "SpellContainerID") }
  statCache[id] = e
  return e
end

-- Text of a field value: loca handles and stats ids ("Target_HoldPerson") become the English display name
local function fieldText(v)
  if type(v) ~= "string" or v == "" then return nil end
  if isHandle(v) then return locaText(v) end
  if isStatId(v) then
    local e = statEntry(v)
    return e and e.name
  end
  return v
end

-- The spell name inside a spell id, for when the stats cannot be read: "Target_Bless_2_AI" -> "Bless",
-- "Projectile_GuidingBolt" -> "GuidingBolt" (normalizes like "Guiding Bolt"). Variant ids ("Target_Command_Halt")
-- give nothing here: they resolve through their container.
local SPELL_KINDS = { Target = true, Projectile = true, Shout = true, Zone = true, Rush = true, Wall = true,
                      Teleportation = true, Throw = true, Cone = true, ProjectileStrike = true, Multistrike = true }
local function idStem(id)
  local kind, rest = id:match("^(%a+)_(.+)$")
  if not (kind and SPELL_KINDS[kind]) then return nil end
  rest = rest:gsub("_AI$", ""):gsub("_Container$", ""):gsub("_%d+$", "")
  if rest:find("_", 1, true) then return nil end
  return rest
end

-- Every normalized name a spell view model can stand for: the field texts, and for a stats id its display name,
-- its container's and the name inside the id
local SPELL_FIELDS = { "DisplayName", "Name", "Title", "IDString" }
function BA.HL.SpellNames(vm)
  local out = {}
  if type(vm) ~= "userdata" and type(vm) ~= "table" then return out end
  local function add(s) if type(s) == "string" and s ~= "" then out[BA.Norm(s)] = true end end
  for _, f in ipairs(SPELL_FIELDS) do
    local v = vmField(vm, f)
    if type(v) == "string" and v ~= "" then
      if isHandle(v) then
        add(locaText(v))
      elseif isStatId(v) then
        local e = statEntry(v)
        if e then
          add(e.name)
          add(statEntry(e.container) and statEntry(e.container).name)
        end
        add(idStem(v))
      else
        add(v)
      end
    end
  end
  return out
end

-- Display label of a view model if it matches a wanted string. A subclass view model also carries a short name
-- ("Light" for Light Domain): the tile shows the short name, but only the full name may match, so the cantrip
-- "Light" never stars the Light Domain tile.
local function vmLabel(dc, wanted)
  if type(dc) ~= "userdata" and type(dc) ~= "table" then return nil end
  local short = fieldText(vmField(dc, "ShortName"))
  local shortNorm = short and BA.Norm(short) or nil
  local first
  for _, f in ipairs(MATCH_FIELDS) do
    local v = fieldText(vmField(dc, f))
    if type(v) == "string" and v ~= "" then
      first = first or v
      local norm = BA.Norm(v)
      if norm ~= "" and norm ~= shortNorm and matches(norm, wanted) then return short or first end
    end
  end
  return nil
end

local function itemLabel(el, wanted) return vmLabel(try(getDC, el), wanted) end

-- View models of choice rows that hold a name (ContentPresenter DataContext types). Rows of these types are
-- matched by name; only the first label TextBlock inside such a row is marked.
local NAMED_VM = { ["ls.VMCharacterCreationPassive"] = true, ["ls.VMSelectableFeat"] = true, ["ls.VMPassive"] = true,
                   ["ls.VMSelectableClass"] = true, ["ls.VMSelectable"] = true, ["ls.VMSelectableRace"] = true,
                   ["ls.VMSelectableOrigin"] = true }
local function isNamedVM(t) return t ~= nil and (NAMED_VM[t] or t:find("VMSelectable", 1, true) ~= nil) end

------------------------------------------------------------------ rainbow outlines
-- Spell icon (SpellIconTemplate): Border "border" > Grid "base" > icon Rectangle, hover Grid, level TextBlock.
-- The Border's own DataContext reads back empty, but the elements inside it read the spell, and so does the list
-- item's ls.VMSpellReference above it. Icons not in a list (spell replacement slots, the class summary's
-- preparable spells) have only the elements inside.
local function isSpellVM(t) return type(t) == "string" and t:match("Spell$") ~= nil end

local function shapeOf(el)
  local first = try(getChild, el, 1)
  return tostring(try(getCount, el) or 0) .. "|" .. tostring(first and try(getType, first))
end

-- The spell view model itself: a VMSpellReference stands for its Spell; nil for other view models
local function asSpell(dc)
  local t = dc and try(getType, dc)
  if t == "ls.VMSpellReference" then return try(getField, dc, "Spell") end
  if t == nil or isSpellVM(t) then return dc end
  return nil
end

-- The spell an icon shows, read from inside the icon (two levels); nil when nothing there reads
local function iconOwnSpell(border)
  local own = asSpell(try(getDC, border))
  if own then return own end
  local level = { border }
  for _ = 1, 2 do
    local deeper = {}
    for _, e in ipairs(level) do
      for i = 1, (try(getCount, e) or 0) do
        local c = try(getChild, e, i)
        if c then
          local s = asSpell(try(getDC, c))
          if s then return s end
          deeper[#deeper + 1] = c
        end
      end
    end
    level = deeper
  end
  return nil
end

-- log: Settings.Debug list of "name, name -> ring / no ring" per icon
local function iconWanted(border, itemSpell, wanted, log)
  local vm = iconOwnSpell(border)
  local names = vm and BA.HL.SpellNames(vm) or {}
  if next(names) == nil and itemSpell then
    vm = itemSpell
    names = BA.HL.SpellNames(vm)
  end
  local want = false
  for norm in pairs(names) do if matches(norm, wanted) then want = true end end
  if log and #log < 200 then
    local l = {}
    for norm in pairs(names) do l[#l + 1] = norm end
    table.sort(l)
    log[#log + 1] = (vm and (#l > 0 and table.concat(l, ", ") or "(no name read)") or "(no spell)")
      .. (want and " -> ring" or " -> no ring")
  end
  return want
end

-- Our brushes live on named Rectangles of the hidden resource widget (GUI/Pages/BuildAdvisorRes.xaml). They are
-- read again on every pass (no long-lived references to game objects).
local painted = {} -- [tostring(element)] = { prop = "Background" | "BorderBrush", orig = value before us }

local function findNamed(root, name, maxDepth)
  local found
  local function go(e, d)
    if found or d > maxDepth then return end
    if try(getName, e) == name then found = e; return end
    for i = 1, (try(getCount, e) or 0) do
      local c = try(getChild, e, i)
      if c then go(c, d + 1) end
      if found then return end
    end
  end
  go(root, 0)
  return found
end

local assetMiss = 0
local function loadAssets(root)
  local A = {}
  -- the widget sits on the HUD layer: a child of ContentRoot (or a few levels below it)
  local content = try(function() return root:Find("ContentRoot") end) or root
  local w
  for i = 1, (try(getCount, content) or 0) do
    local c = try(getChild, content, i)
    if c and try(getName, c) == ASSET_WIDGET then w = c; break end
  end
  if not w and assetMiss % RETRY_PASSES == 0 then w = findNamed(root, ASSET_WIDGET, 8) end
  if not w then assetMiss = assetMiss + 1; return A end
  local function fill(n)
    local e = findNamed(w, n, 6)
    return e and try(getProp, e, "Fill")
  end
  A.tile, A.icon, A.clear = fill("BA_TileRing"), fill("BA_IconRing"), fill("BA_Clear")
  return A
end

-- Paint (want = true) or restore (want = false) one element's outline property
local function outline(el, prop, brush, want, A)
  local k = tostring(el)
  local p = painted[k]
  if want and brush then
    if not p then
      p = { prop = prop, orig = try(getProp, el, prop) }
      painted[k] = p
    end
    -- An unset brush reads as nil, and comparing nil with a brush object raises an error in Script Extender, which
    -- ended the whole pass before any star or outline was drawn.
    local cur = try(getProp, el, prop)
    if cur == nil or not try(function() return cur == brush end) then pcall(setProp, el, prop, brush) end
    return true
  elseif p then
    local back = p.orig
    if back == nil then back = A.clear end -- no ClearValue in the extender: put a transparent brush back
    if back ~= nil then pcall(setProp, el, p.prop, back) end
    painted[k] = nil
  end
  return false
end

------------------------------------------------------------------ ability rows
-- Point-buy rows (character creation / respec) and the ability rows of Ability Improvement and of feats with an
-- ability choice (level-up) have an ls.VMAbility DataContext (Ability = "Strength"). The ability name gets the
-- plan appended: "Strength (17, +2)" = reach 17, the +2 goes here; "Dexterity (10)" = no bonus. Never a star.
-- The name column holds about 18 characters before the row's "-" button: "Charisma (17, +2)" fits, "Constitution
-- (16, +1)" ran under the button. A longer text uses the game's short name instead: "CON (16, +1)".

local ABILITY_KEY = { Strength = "STR", Dexterity = "DEX", Constitution = "CON", Intelligence = "INT", Wisdom = "WIS", Charisma = "CHA" }

-- Strip what we appended: "Strength (17, +2)" -> "Strength"
local function stripAbilitySuffix(t) return (t:gsub("%s+%(%d+[^)]*%)$", "")) end

local function abilitySuffix(plan)
  local s = " (" .. plan.final
  if plan.bonus > 0 then s = s .. ", +" .. plan.bonus end
  return s .. ")"
end

local ABILITY_TEXT_MAX = 18
local function abilityText(name, plan)
  if not plan then return name end
  local t = name .. abilitySuffix(plan)
  if #t > ABILITY_TEXT_MAX and ABILITY_KEY[name] then t = ABILITY_KEY[name] .. abilitySuffix(plan) end
  return t
end

-- row: the element holding the VMAbility DataContext; plan: { final, bonus } or nil.
-- Row layout: [Image..., Control > TextBlock (name, bound: reads nil), LSButton (-), TextBlock (value),
-- LSButton (+)]. Only rows with buttons are touched (the summary panels reuse VMAbility for their labels).
-- onlyPlanned: level-up - rows the plan does not raise stay as they are (a suffix we added earlier is removed).
local function decorateAbilityRow(row, name, plan, onlyPlanned)
  local nameTB, boundName, hasButton, current
  local function scan(el, depth, parentTy)
    if depth > 12 then return end
    local ty = try(getType, el)
    if ty and ty:find("Button", 1, true) then hasButton = true end
    if not nameTB and isTextType(ty) then
      local t = try(getText, el)
      if type(t) == "string" and t ~= "" and t ~= BOUND_PLACEHOLDER and not t:match("^%d+$") then
        local bare = BA.Norm(stripAbilitySuffix(t))
        if bare == BA.Norm(name) or bare == BA.Norm(ABILITY_KEY[name] or name) then nameTB = el; current = t end
      elseif (t == nil or t == "" or t == BOUND_PLACEHOLDER) and parentTy == "Control" and not boundName then
        boundName = el
      end
    end
    for i = 1, (try(getCount, el) or 0) do
      local c = try(getChild, el, i)
      if c then scan(c, depth + 1, ty) end
    end
  end
  scan(row, 0, nil)
  local target = nameTB or boundName
  if not (target and hasButton) then return false end
  local text = abilityText(name, plan)
  if onlyPlanned and not plan and not (current and current ~= name) then return true end -- untouched row
  if current ~= text then try(setText, target, text) end
  return true
end

------------------------------------------------------------------ skill proficiencies
-- The summary line ("Athletics, Religion, Insight, ...") is plain text. When it lacks any of the build's
-- skills, the "Change" button that follows it is marked so the player knows to open the picker.

local SKILLS = {} -- normalized -> display name ("sleightofhand" -> "Sleight of Hand")
for _, s in ipairs({ "Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", "History", "Insight",
  "Intimidation", "Investigation", "Medicine", "Nature", "Perception", "Performance", "Persuasion", "Religion",
  "Sleight of Hand", "Stealth", "Survival" }) do SKILLS[BA.Norm(s)] = s end
local CHANGE = "Change"

-- Set of normalized skills in a comma list, or nil when the text is not a skill list
local function skillList(text)
  if not text:find(",", 1, true) then return nil end
  local set, n = {}, 0
  for part in text:gmatch("[^,]+") do
    local norm = BA.Norm(part)
    if not SKILLS[norm] then return nil end
    set[norm] = true; n = n + 1
  end
  return n >= 2 and set or nil
end

-- wanted: table normalized -> original string; nil/empty = restore everything
-- abilityPlan: { STR = { final = 17, bonus = 2 }, ... } or nil
-- skillPlan: { "Athletics", ... } or nil
-- opts: { onlyPlannedAbilities = true } at level-up (ability improvement rows)
function BA.HL.Apply(wanted, abilityPlan, skillPlan, opts)
  wanted = wanted or {}
  opts = opts or {}
  local root = try(Ext.UI.GetRoot)
  if not root then return end
  local t0 = try(Ext.Utils.MonotonicTime) or 0
  local hasWanted = next(wanted) ~= nil
  local budget, count = NODE_BUDGET, 0
  local rows = {}
  pass = pass + 1
  local skillsHave, changeTB, changeBtn -- current skill summary, the "Change" label / button after it
  local skillsVM, skillVMSeen = {}, false
  local A = (hasWanted or next(painted)) and loadAssets(root) or {}
  local outlines = 0

  -- once: limits which bound TextBlocks inside a matched row get the label:
  --  { image = false } skill picker rows: the picker has separate name / value columns with the same view model;
  --                    only the name column's row holds the proficiency icon (an Image, visited before the name)
  --  { first = true }  named choice rows: only the first label (the name; a second one is a source / value)
  -- Settings.Debug: write what the skill-summary / Change-button search saw to BuildAdvisor_debug.txt
  local debug = BA.Settings and BA.Settings.Debug
  local stack, summaryAnc, commaTexts, panelAnc = {}, nil, {}, nil
  local spellLog = debug and {} or nil

  -- spell: the spell of the list item being walked (from its ls.VMSpellReference ContentPresenter), passed down
  -- to that item's icon only; false = the item holds no spell (an empty slot)
  local function walk(el, depth, label, once, spell)
    if budget <= 0 or depth > 80 then return end
    budget = budget - 1
    if debug then stack[depth] = el end
    local ty = try(getType, el)
    if hasWanted and isItemType(ty) then label = itemLabel(el, wanted); once = nil end
    local key = (ty == "ContentPresenter") and tostring(el) or nil
    local shape = key and unreadableDC[key] and shapeOf(el)
    if key and (not unreadableDC[key] or unreadableDC[key] ~= shape or pass % RETRY_PASSES == 0) then
      local dc = try(getDC, el)
      unreadableDC[key] = (dc == nil) and (shape or shapeOf(el)) or nil
      local dcType = dc and try(getType, dc)
      if dcType == "ls.VMSpellReference" then
        spell = try(getField, dc, "Spell") or false
      elseif isSpellVM(dcType) then
        spell = dc
      end
      if hasWanted and dcType == "ls.VMCharacterCreationSkill" then
        -- skill picker row: Skill = "SleightOfHand"; its name TextBlock is bound
        local sk = try(getField, dc, "Skill")
        local norm = type(sk) == "string" and BA.Norm(sk) or ""
        -- only the first bound TextBlock is the name; the next one is the "+5" value
        if norm ~= "" and matches(norm, wanted) then label = SKILLS[norm] or sk; once = { image = false } end
      elseif hasWanted and not label and isNamedVM(dcType) then
        local l = vmLabel(dc, wanted)
        if l then label = l; once = { first = true } end
      end
      if dcType == "ls.VMSkill" then -- the picker's VMCharacterCreationSkill rows go stale after Confirm
        -- current proficiencies straight from the view models (the summary line is bound text)
        local sk = try(getField, dc, "Skill")
        if type(sk) == "string" then
          skillVMSeen = true
          if try(getField, dc, "IsProficient") == true then skillsVM[BA.Norm(sk)] = true end
        end
      end
      if dcType == "ls.VMAbility" then
        local name, base = try(getField, dc, "Ability"), try(getField, dc, "BaseValue")
        -- BaseValue 0 = hidden duplicate panel
        if ABILITY_KEY[name] and (base == nil or (type(base) == "number" and base > 0)) then
          rows[#rows + 1] = { el, name }
          if debug and not panelAnc then panelAnc = stack[math.max(0, depth - 6)] end
        end
      end
    end

    -- spell / cantrip icon: the 4-pixel Border "border" of SpellIconTemplate
    if ty == "Border" and try(getName, el) == "border" then
      local want = hasWanted and iconWanted(el, spell, wanted, spellLog)
      if outline(el, "BorderBrush", A.icon, want, A) then outlines = outlines + 1 end
    end

    if once and ty == "Image" then once.image = true end
    if isTextType(ty) then
      local text = try(getText, el)
      if type(text) == "string" and stripMark(text) == CHANGE then
        if not changeTB then changeTB = el end
        text = nil -- handled after the walk
      elseif type(text) == "string" and not skillsHave then
        skillsHave = skillList((text:gsub("%s+", " ")))
        if debug and text:find(",", 1, true) and #commaTexts < 20 then commaTexts[#commaTexts + 1] = text end
        if debug and skillsHave and not summaryAnc then summaryAnc = stack[math.max(0, depth - 4)] end
      end
      local blocked = once and ((once.image == false) or once.done)
      if label and (text == nil or text == "" or text == BOUND_PLACEHOLDER) then
        -- bound label inside a recommended list item
        if not blocked and pcall(setText, el, MARK .. label) then count = count + 1 end
        if once and once.first then once.done = true end
      elseif type(text) == "string" and text ~= "" and text ~= BOUND_PLACEHOLDER and #text < 64 then
        local plain, marked = stripMark(text)
        local norm = BA.Norm(plain)
        local want = norm ~= "" and matches(norm, wanted)
        if want and not marked then
          if pcall(setText, el, MARK .. plain) then count = count + 1 end
        elseif marked and not want and not (label and BA.Norm(label) == norm) then
          try(setText, el, plain)
        elseif want then
          count = count + 1
        end
        if once and once.first and label and BA.Norm(label) == norm then once.done = true end
      end
    end

    -- Skill box: Skill Proficiencies header, a WrapPanel of VMSkill items, then the "Change" toggle button
    -- (ls.LSToggleButton) whose label is bound
    if (skillsHave or skillVMSeen) and not changeBtn and not changeTB and ty == "ls.LSToggleButton" then changeBtn = el end
    local cnt = try(getCount, el) or 0
    -- tile: a Grid holding the picture and the game's "frame" selector (LSNineSliceImage) of a list item
    local tileGrid = ty == "Grid" and (label ~= nil or painted[tostring(el)] ~= nil)
    for i = 1, cnt do -- VisualChild is 1-based in the Script Extender
      local c = try(getChild, el, i)
      if c then
        if tileGrid and try(getName, c) == "frame" and (try(getType, c) or ""):find("NineSlice", 1, true) then
          if outline(el, "Background", A.tile, label ~= nil, A) then outlines = outlines + 1 end
        end
        walk(c, depth + 1, label, once, spell)
      end
    end
  end

  walk(root, 0, nil)
  BA.HL.ms = (try(Ext.Utils.MonotonicTime) or 0) - t0
  BA.HL.nodes = NODE_BUDGET - budget
  if debug then
    local out = { "walk: " .. tostring(BA.HL.ms) .. " ms, " .. BA.HL.nodes .. " nodes", "summary found: " .. tostring(skillsHave ~= nil), "changeTB: " .. tostring(changeTB and try(getText, changeTB)),
                  "changeBtn: " .. tostring(changeBtn and try(getType, changeBtn)), "outlines: " .. outlines,
                  "assets: " .. tostring(A.tile ~= nil) .. " " .. tostring(A.icon ~= nil), "spell icons:" }
    for _, t in ipairs(spellLog) do out[#out + 1] = "  " .. t end
    out[#out + 1] = "comma texts:"
    for _, t in ipairs(commaTexts) do out[#out + 1] = "  " .. t end
    local function dump(e, d)
      if d > 16 or #out > 4000 then return end
      local t = try(getText, e)
      local dc = (try(getType, e) == "ContentPresenter" or isTextType(try(getType, e))) and try(getDC, e)
      out[#out + 1] = string.rep("  ", d) .. tostring(try(getType, e)) .. (t ~= nil and (" text=" .. tostring(t)) or "")
        .. (dc and (" dc=" .. tostring(try(getType, dc))) or "")
      for i = 1, (try(getCount, e) or 0) do local c = try(getChild, e, i); if c then dump(c, d + 1) end end
    end
    if summaryAnc then out[#out + 1] = "subtree 4 levels above summary:"; dump(summaryAnc, 0) end
    out[#out + 1] = "ability rows: " .. #rows
    if panelAnc then out[#out + 1] = "subtree 6 levels above first ability row:"; dump(panelAnc, 0) end
    out[#out + 1] = "skills from view models: " .. tostring(skillVMSeen)
    for k in pairs(skillsVM) do out[#out + 1] = "  proficient: " .. k end
    if BA.HL.pointBuySeen and not BA.HL.treeDumped then -- set by the previous pass
      BA.HL.treeDumped = true
      local tree = {}
      local function full(e, d)
        if d > 60 or #tree > 12000 then return end
        local ty = try(getType, e)
        local t = isTextType(ty) and try(getText, e) or nil
        local dc = (ty == "ContentPresenter" or isTextType(ty) or ty == "Border") and try(getDC, e)
        tree[#tree + 1] = string.rep(" ", d) .. tostring(ty) .. " " .. tostring(try(getName, e) or "")
          .. (t ~= nil and (" text=" .. tostring(t)) or "") .. (dc and (" dc=" .. tostring(try(getType, dc))) or "")
        for i = 1, (try(getCount, e) or 0) do local c = try(getChild, e, i); if c then full(c, d + 1) end end
      end
      full(root, 0)
      pcall(Ext.IO.SaveFile, "BuildAdvisor_tree.txt", table.concat(tree, "\n"))
    end
    local txt = table.concat(out, "\n")
    if txt ~= BA.HL.lastDebug then BA.HL.lastDebug = txt; pcall(Ext.IO.SaveFile, "BuildAdvisor_debug.txt", txt) end
  end
  for _, r in ipairs(rows) do
    local plan = abilityPlan and abilityPlan[ABILITY_KEY[r[2]]]
    local ok, did = pcall(decorateAbilityRow, r[1], r[2], plan, opts.onlyPlannedAbilities)
    if ok and did then BA.HL.pointBuySeen = true end
  end
  if skillVMSeen and next(skillsVM) then skillsHave = skillsVM end
  if not changeTB and changeBtn then
    local function firstText(e, d)
      if d > 8 then return nil end
      if isTextType(try(getType, e)) then return e end
      for i = 1, (try(getCount, e) or 0) do
        local c = try(getChild, e, i)
        local t = c and firstText(c, d + 1)
        if t then return t end
      end
    end
    changeTB = firstText(changeBtn, 0)
  end
  if changeTB and skillsHave then
    local missing = false
    for _, sk in ipairs(skillPlan or {}) do if not skillsHave[BA.Norm(sk)] then missing = true end end
    local cur = try(getText, changeTB)
    if missing then
      if cur ~= MARK .. CHANGE then try(setText, changeTB, MARK .. CHANGE) end
    elseif cur == MARK .. CHANGE then
      try(setText, changeTB, CHANGE)
    end
  end
  BA.HL.outlines = outlines
  BA.HL.active = hasWanted or #rows > 0 or next(painted) ~= nil
  return count
end

function BA.HL.Clear()
  if BA.HL.active then BA.HL.Apply({}, nil, nil, { onlyPlannedAbilities = true }) end
  unreadableDC = {}
  painted = {}
  BA.HL.active = false
end
