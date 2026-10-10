-- The "Build Advisor" overlay window (Script Extender IMGUI).

BA = BA or {}
BA.UI = {}

-- Colours close to the game's own panels: parchment text, muted gold headings
local TEXT  = { 0.90, 0.85, 0.76, 1.0 }
local GOLD  = { 0.91, 0.76, 0.48, 1.0 }
local GREY  = { 0.66, 0.62, 0.56, 1.0 }
local GREEN = { 0.56, 0.86, 0.46, 1.0 }
local AMBER = { 1.0, 0.71, 0.32, 1.0 }
local RED   = { 1.0, 0.46, 0.40, 1.0 }
local FRAME = { 0.58, 0.47, 0.29, 0.8 }

-- applied to the window, so every widget inside inherits it
local WINDOW_COLORS = {
  Text = TEXT, CheckMark = GOLD, Border = FRAME, Separator = FRAME,
  TitleBgActive = { 0.30, 0.23, 0.14, 1.0 },
  Header = { 0.25, 0.20, 0.14, 0.85 }, HeaderHovered = { 0.38, 0.29, 0.19, 0.9 }, HeaderActive = { 0.45, 0.35, 0.22, 0.9 },
  TableRowBg = { 0.17, 0.14, 0.11, 0.55 }, TableRowBgAlt = { 0.11, 0.09, 0.08, 0.55 },
}

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end

local function viewport()
  local vp = try(Ext.IMGUI.GetViewportSize)
  local vw, vh = vp and vp[1], vp and vp[2]
  if type(vw) ~= "number" or vw <= 0 or type(vh) ~= "number" or vh <= 0 then return nil end
  return vw, vh
end

-- IMGUI text does not wrap here, so long lines are split by hand. Script Extender scales its font with the
-- viewport height; measured in game, one character is about 0.00624 x viewport height x font scale pixels wide.
local CHAR_PER_VH = 0.00624
local function maxChars()
  local _, vh = viewport()
  if not vh or not BA.UI.widthPx then return 80 end
  local scale = BA.Settings.FontScale or 0.75
  return math.max(40, math.floor(BA.UI.widthPx / (CHAR_PER_VH * vh * scale)) - 3)
end

local function wrap(s, limit)
  local lines, line = {}, ""
  for word in s:gmatch("%S+") do
    if line ~= "" and #line + 1 + #word > limit then lines[#lines + 1] = line; line = word
    else line = (line == "") and word or (line .. " " .. word) end
  end
  if line ~= "" or #lines == 0 then lines[#lines + 1] = line end
  return lines
end

local function colored(t, color)
  if color then try(function() t:SetColor("Text", color) end) end
  return t
end

local function text(parent, s, color)
  local first
  for _, l in ipairs(wrap(s, maxChars())) do
    local t = colored(parent:AddText(l), color)
    first = first or t
  end
  return first
end

local function bullet(parent, s, color)
  local lines = wrap(s, maxChars() - 3)
  local first = colored(parent:AddBulletText(lines[1]), color)
  for i = 2, #lines do colored(parent:AddText("    " .. lines[i]), color) end
  return first
end

-- a choice under a bullet ("Class: Fighter" -> "- Fighting Style: ...")
local function subItem(parent, s, color)
  local lines = wrap(s, maxChars() - 9)
  local first = colored(parent:AddText("      - " .. lines[1]), color)
  for i = 2, #lines do colored(parent:AddText("        " .. lines[i]), color) end
  return first
end

function BA.UI.Init()
  local w = Ext.IMGUI.NewWindow("Build Advisor")
  w.Closeable = true
  w.Open = false
  for name, color in pairs(WINDOW_COLORS) do try(function() w:SetColor(name, color) end) end
  try(function() w:SetStyle("WindowBorderSize", 1) end)
  -- Smaller text so the plan fits (global IMGUI setting; settings file key FontScale)
  try(function() Ext.IMGUI.SetFontScaleMultiplier(BA.Settings.FontScale or 0.75) end)
  w.OnClose = function() BA.UI.userClosed = true end
  BA.UI.window = w

  local combo = w:AddCombo("Build")
  combo.OnChange = function(c)
    local entry = BA.UI.ranked and BA.UI.ranked[c.SelectedIndex + 1]
    if entry and BA.UI.charKey then
      BA.Settings.Choices[BA.UI.charKey] = entry.build.id
      BA.SaveSettings()
      BA.Refresh(true)
    end
  end
  BA.UI.combo = combo

  local cbAll = w:AddCheckbox("Show all builds", BA.Settings.ShowAll)
  cbAll.OnChange = function(c) BA.Settings.ShowAll = c.Checked; BA.SaveSettings(); BA.Refresh(true) end
  local cbHl = w:AddCheckbox("Highlight in game menus", BA.Settings.Highlight)
  cbHl.SameLine = true
  cbHl.OnChange = function(c)
    BA.Settings.Highlight = c.Checked; BA.SaveSettings()
    if not c.Checked then BA.HL.Run(BA.HL.Clear) end
    BA.Refresh(true)
  end
  local cbAuto = w:AddCheckbox("Auto-open", BA.Settings.AutoOpen)
  cbAuto.SameLine = true
  cbAuto.OnChange = function(c) BA.Settings.AutoOpen = c.Checked; BA.SaveSettings() end

  w:AddSeparator()
  BA.UI.content = w:AddGroup("content")
end

-- While the game's pause menu is open the window is closed and remembered (BA.UI.reopen), then opened again; the
-- hotkey and the screen auto-open only change what happens after the menu.
function BA.UI.SetMenuHidden(on)
  local w = BA.UI.window
  if not w or BA.UI.menuHidden == on then return end
  BA.UI.menuHidden = on
  if on then
    BA.UI.reopen = w.Open == true
    w.Open = false
  elseif BA.UI.reopen then
    BA.UI.reopen = false
    w.Open = true
    BA.Refresh(true)
  end
end

function BA.UI.Toggle()
  if not BA.UI.window then return end
  if BA.UI.menuHidden then
    BA.UI.reopen = not BA.UI.reopen
    BA.UI.userClosed = not BA.UI.reopen
    return
  end
  BA.UI.window.Open = not BA.UI.window.Open
  BA.UI.userClosed = not BA.UI.window.Open
  if BA.UI.window.Open then BA.Refresh(true) end
end

function BA.UI.Show()
  local w = BA.UI.window
  if BA.UI.menuHidden then BA.UI.reopen = true; return end
  if w and not w.Open then
    w.Open = true
    BA.Refresh(true)
  end
end

function BA.UI.Hide()
  if BA.UI.menuHidden then BA.UI.reopen = false; return end
  if BA.UI.window and BA.UI.window.Open then BA.UI.window.Open = false end
end

------------------------------------------------------------------ placement
-- The game lays out its creation, respec and level-up pages on a 3840 x 2160 canvas scaled to the screen height
-- (CharacterCreation.xaml, CharacterRespec.xaml, CharacterLevelUp.xaml in Game.pak). The left selection panel is the
-- contentPane image (1284 x 1908) placed at (320, 62); its gold frame runs from x 88 to 1194 and from y 86 to 1790
-- of that image. The summary panel on the right hangs from the right edge; its widest part starts about 790 canvas
-- units from it (measured on a 2560 x 1600 screenshot).
local CANVAS_H = 2160
local PANEL_RIGHT, PANEL_TOP, PANEL_BOTTOM = 320 + 1194, 62 + 86, 62 + 1790
local GAP, RIGHT_CLEAR, MIN_W, MAX_W = 16, 790, 900, 1500

-- Beside the left panel with the same top and bottom: { x, y }, { width, height } in pixels
function BA.UI.DockRect(vw, vh)
  local s = vh / CANVAS_H
  local left = (PANEL_RIGHT + GAP) * s
  local right = math.min(vw - RIGHT_CLEAR * s, left + MAX_W * s)
  right = math.max(right, left + MIN_W * s)
  return { left, PANEL_TOP * s }, { right - left, (PANEL_BOTTOM - PANEL_TOP) * s }
end

-- Outside the menus: the gap between where the selection panel (left ~44%) and the summary panel (right ~20%) are
function BA.UI.FreeRect(vw, vh)
  local left, right, margin = vw * 0.44, vw * 0.80, vw * 0.008
  return { left + margin, vh * 0.03 }, { right - left - 2 * margin, vh * 0.55 }
end

local function vec2(v)
  if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" then return v end
  if type(v) == "userdata" then
    local x, y = try(function() return v[1] end), try(function() return v[2] end)
    if type(x) == "number" and type(y) == "number" then return { x, y } end
  end
  return nil
end

local function near(a, b) return math.abs(a[1] - b[1]) <= 3 and math.abs(a[2] - b[2]) <= 3 end

-- Once the window has been seen where it was put, any other position or size is the player's: from then on the
-- window stays where they left it for the rest of the session.
local function noticeUserMove()
  local w, p = BA.UI.window, BA.UI.placement
  if not w or not p or BA.UI.userPlaced then return end
  local pos, size = vec2(try(function() return w.LastPosition end)), vec2(try(function() return w.LastSize end))
  if not pos or not size then return end
  if near(pos, p.pos) and near(size, p.size) then
    p.seen = true
  elseif p.seen then
    BA.UI.userPlaced = true
    BA.UI.widthPx = size[1]
  else
    -- the game never showed it exactly there (clamped to the screen): take what it shows as the placement
    p.checks = p.checks + 1
    if p.checks >= 4 then p.pos, p.size, p.seen = pos, size, true; BA.UI.widthPx = size[1] end
  end
end

-- inMenu: creation, respec or level-up is on screen
function BA.UI.Place(inMenu)
  local w = BA.UI.window
  if not w or w.Open ~= true then return end
  noticeUserMove()
  if BA.UI.userPlaced then return end
  local kind = inMenu and "menu" or "free"
  if BA.UI.placement and BA.UI.placement.kind == kind then return end
  local vw, vh = viewport()
  if not vw then return end
  local pos, size = (inMenu and BA.UI.DockRect or BA.UI.FreeRect)(vw, vh)
  try(function() w:SetPos(pos, "Always") end)
  try(function() w:SetSize(size, "Always") end)
  BA.UI.placement = { kind = kind, pos = pos, size = size, checks = 0 }
  BA.UI.widthPx = size[1]
end

-- Called from the tick while the window is open: notices a move or resize by the player and re-wraps the text
-- after a resize
function BA.UI.Watch()
  local w = BA.UI.window
  if not w or w.Open ~= true or BA.UI.menuHidden then return end
  local before = BA.UI.widthPx
  noticeUserMove()
  local size = BA.UI.userPlaced and vec2(try(function() return w.LastSize end))
  if size then BA.UI.widthPx = size[1] end
  if before and BA.UI.widthPx and math.abs(BA.UI.widthPx - before) > 8 then BA.Refresh(true) end
end

------------------------------------------------------------------ content
local function resetContent()
  if BA.UI.content then try(function() BA.UI.content:Destroy() end) end
  BA.UI.content = BA.UI.window:AddGroup("content")
  return BA.UI.content
end

local function describeChar(ctx)
  local parts = { ctx.name or "Unnamed" }
  if ctx.origin and BA.OriginKey(ctx) ~= "generic" and BA.OriginLabel(ctx.origin) ~= ctx.name then
    parts[1] = parts[1] .. " (" .. BA.OriginLabel(ctx.origin) .. ")"
  end
  if ctx.race then parts[#parts + 1] = tostring(ctx.race.display) end
  local cls = {}
  for _, c in ipairs(ctx.classes or {}) do
    cls[#cls + 1] = c.display .. (c.sub and (" [" .. c.sub .. "]") or "") .. " " .. tostring(c.level)
  end
  if #cls > 0 then parts[#parts + 1] = table.concat(cls, " / ") end
  return table.concat(parts, " - ")
end

local function screenName(ctx)
  if ctx.mode == "Character Creation" then return "New character" end
  if ctx.mode == "Level Up" then return "Level up to " .. tostring(ctx.level) end
  if ctx.mode == "Party" then return "Party" end
  return ctx.mode
end

-- why this build, in one line: the ranking reason plus the origin's advice (its "<Race> (locked)." opening is
-- already on the race line)
local function whyLine(ctx, entry)
  local s = entry.reason
  local origin = BA.OriginInfo(ctx)
  if origin and origin.note and BA.OriginKey(ctx) ~= "generic" then
    local note = origin.note:gsub("^[^.]-%(locked%)%.%s*", "")
    if note ~= "" then s = s .. ". " .. note end
  end
  return s
end

local function raceLine(ctx, b)
  local s
  if BA.RaceLocked(ctx) and ctx.race then
    s = "Race: " .. tostring(ctx.race.display) .. " (locked for " .. BA.OriginLabel(ctx.origin) .. ")"
  else
    s = "Race: " .. b.races[1]
    if #b.races > 1 then s = s .. " (or " .. table.concat(b.races, ", ", 2) .. ")" end
  end
  if b.raceHl then s = s .. "; race choice: " .. table.concat(b.raceHl, ", ") end
  return s
end

-- What the window shows, as rows { style, text }. Styles: title, sep, gold, note, item, sub, ok, warn, bad.
-- main: always visible; about: the folded "About this build" section. Pure: tested offline.
function BA.UI.Outline(ctx, entry, analysis)
  local main, about = {}, {}
  local function add(rows, style, s) rows[#rows + 1] = { style = style, text = s } end
  local b = entry.build
  local creation = ctx.mode == "Character Creation" or ctx.mode == "Respec"
  local party = ctx.mode == "Party"

  add(main, "title", screenName(ctx) .. ": " .. describeChar(ctx))
  add(main, "sep", b.name)
  add(main, "gold", "Tier " .. b.tier .. " - " .. b.role)
  add(main, "note", whyLine(ctx, entry))

  -- what to pick on this screen, in the order the game asks
  local step = party and analysis.nextStep or analysis.step
  local stepLevel = party and analysis.level + 1 or analysis.level
  add(main, "sep", party and ("Next level-up: level " .. stepLevel) or "Do this now")
  if creation then add(main, "item", raceLine(ctx, b)) end
  if step then
    add(main, "item", creation and ("Class: " .. step.cls) or string.format("Level %d: %s", stepLevel, step.cls))
    for _, p in ipairs(step.picks) do
      -- creation lists every skill below; the class's share would say it twice
      if not (creation and p:find("^Skills:")) then add(main, "sub", p) end
    end
  else
    add(main, "item", "Build complete (level 12).")
  end
  if creation then
    add(main, "item", "Background: " .. b.background)
    local ab = {}
    for _, k in ipairs(BA.ABILITIES) do ab[#ab + 1] = k .. " " .. b.base[k] end
    add(main, "item", "Abilities: " .. table.concat(ab, ", ") .. " (+2 " .. b.plus2 .. ", +1 " .. b.plus1 .. ")")
    add(main, "item", "Skills: " .. table.concat(b.skills, ", "))
    if b.deity then add(main, "item", "Deity: " .. b.deity .. " (no rules effect)") end
  end

  -- the current choices: what matches in one line, each thing to change on its own
  local ok, fix, abilityChecks, abilitiesOk = {}, {}, 0, true
  for _, chk in ipairs(analysis.checks) do
    if chk.minor then
      abilityChecks = abilityChecks + 1
      if not chk.ok then abilitiesOk = false; fix[#fix + 1] = chk end
    elseif not chk.locked then
      if chk.ok then ok[#ok + 1] = chk.label or chk.text else fix[#fix + 1] = chk end
    end
  end
  if abilityChecks > 0 and abilitiesOk then ok[#ok + 1] = "abilities" end
  if #ok + #fix + #analysis.warnings > 0 then add(main, "sep", "Your choices") end
  if #ok > 0 then add(main, "ok", (#fix == 0 and "All match the plan: " or "Matches the plan: ") .. table.concat(ok, ", ")) end
  for _, chk in ipairs(fix) do add(main, chk.minor and "warn" or "bad", chk.text) end
  for _, wmsg in ipairs(analysis.warnings) do add(main, "warn", wmsg) end

  add(about, "text", b.why)
  if creation and b.raceWhy then add(about, "text", "Race: " .. b.raceWhy) end
  if b.note then add(about, "text", b.note) end
  add(about, "note", "Respec any time at camp with Withers (100 gold). The mod follows you through every level-up after a respec.")
  return { main = main, about = about }
end

local ROW = {
  title = function(p, s) text(p, s, GOLD) end,
  sep   = function(p, s) colored(p:AddSeparatorText(s), GOLD) end,
  gold  = function(p, s) text(p, s, GOLD) end,
  note  = function(p, s) text(p, s, GREY) end,
  text  = function(p, s) text(p, s) end,
  item  = function(p, s) bullet(p, s) end,
  sub   = function(p, s) subItem(p, s) end,
  ok    = function(p, s) bullet(p, s, GREEN) end,
  warn  = function(p, s) bullet(p, s, AMBER) end,
  bad   = function(p, s) bullet(p, s, RED) end,
}
local function rows(parent, list) for _, r in ipairs(list) do ROW[r.style](parent, r.text) end end

-- ctx: detection result (may be nil); ranked: { {build, reason} }; analysis: BA.Analyse result
function BA.UI.Render(ctx, ranked, selectedIdx, analysis)
  if not BA.UI.window then return end
  BA.UI.ranked = ranked
  BA.UI.Place(BA.IsCreationMode(ctx))

  local names = {}
  for i, e in ipairs(ranked or {}) do
    names[i] = (i == 1 and "[Recommended] " or "") .. e.build.name .. "  (" .. e.build.tier .. ")"
  end
  BA.UI.combo.Options = names
  BA.UI.combo.SelectedIndex = math.max(0, (selectedIdx or 1) - 1)

  local c = resetContent()
  local footer = BA.Settings.Hotkey .. " shows or hides this window. In the game's menus the recommended choices get a star (*) and an outline."
  if not ctx then
    text(c, "No character found. Start a new game, use Withers' respec, or level up a party member.", GREY)
    text(c, footer, GREY)
    return
  end
  local entry = ranked and ranked[selectedIdx or 1]
  if not entry then return end
  local b = entry.build
  local outline = BA.UI.Outline(ctx, entry, analysis)
  rows(c, outline.main)

  c:AddSpacing()
  rows(c:AddCollapsingHeader("About this build"), outline.about)

  local stepLevel = (ctx.mode == "Party") and analysis.level + 1 or analysis.level
  local hdr = c:AddCollapsingHeader("Full level 1-12 plan")
  local tbl = hdr:AddTable("plan", 3)
  try(function() tbl.Borders = true; tbl.RowBg = true end)
  try(function()
    tbl:AddColumn("Lvl", "WidthFixed", 32)
    tbl:AddColumn("Class", "WidthFixed", 80)
    tbl:AddColumn("Choices", "WidthStretch")
  end)
  for i, lv in ipairs(b.levels) do
    local row = tbl:AddRow()
    local color = (i == stepLevel) and GOLD or ((i < stepLevel) and GREY or nil)
    text(row:AddCell(), tostring(i), color)
    text(row:AddCell(), lv.cls, color)
    text(row:AddCell(), table.concat(lv.picks, "; "), color)
  end

  -- the build's gear sets from Loot Advisor: one folded section per set, a list per act inside
  local gear = BA.Gear.Outline(ctx, b, BA.Gear.Api())
  c:AddSpacing()
  if gear.header then colored(c:AddSeparatorText(gear.header), GOLD) end
  for _, set in ipairs(gear.sets) do
    local h = c:AddCollapsingHeader(set.title)
    for _, act in ipairs(set.acts) do
      text(h, act.title, GOLD)
      for _, line in ipairs(act.items) do bullet(h, line) end
    end
  end
  text(c, gear.ref, GREY)

  c:AddSpacing()
  text(c, footer, GREY)
end
