-- The "Build Advisor" overlay window (Script Extender IMGUI).

BA = BA or {}
BA.UI = {}

local GREEN = { 0.45, 1.0, 0.45, 1.0 }
local RED   = { 1.0, 0.45, 0.45, 1.0 }
local GOLD  = { 1.0, 0.8, 0.3, 1.0 }
local GREY  = { 0.7, 0.7, 0.7, 1.0 }

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end

-- IMGUI text does not wrap here, so long lines are split by hand. Measured in game: one character is
-- about 0.0039 x viewport width x font scale, so the limit follows the window width (as a share of the
-- viewport) and the font scale, independent of resolution.
BA.UI.widthShare = 0.328 -- window width / viewport width (default placement)
local function maxChars()
  local scale = BA.Settings.FontScale or 0.75
  return math.max(40, math.floor(BA.UI.widthShare / (0.0039 * scale)) - 3)
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

function BA.UI.Init()
  local w = Ext.IMGUI.NewWindow("Build Advisor")
  w.Closeable = true
  w.Open = false
  -- Smaller text so the plan fits (global IMGUI setting; settings file key FontScale)
  try(function() Ext.IMGUI.SetFontScaleMultiplier(BA.Settings.FontScale or 0.75) end)
  w.OnClose = function() BA.UI.userClosed = true end
  BA.UI.window = w

  text(w, "Hotkey: " .. BA.Settings.Hotkey .. " toggles this window. In the game menus every recommended choice gets a star (*); recommended tiles and spell icons also get a rainbow outline.", GREY)

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

local placeDefault -- defined below, next to Show

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
  if not BA.UI.window.Open and not BA.UI.placed then placeDefault(BA.UI.window); BA.UI.placed = true end
  BA.UI.window.Open = not BA.UI.window.Open
  BA.UI.userClosed = not BA.UI.window.Open
  if BA.UI.window.Open then BA.Refresh(true) end
end

-- Default spot: the gap between the game's selection panel (left ~44% of the screen) and its summary
-- panel (right ~20%). Applied once per session on first show; the player can move / resize it after.
placeDefault = function(w)
  local vp = try(Ext.IMGUI.GetViewportSize)
  local vw, vh = vp and vp[1], vp and vp[2]
  if type(vw) ~= "number" or vw <= 0 then return end
  local left, right, margin = vw * 0.44, vw * 0.80, vw * 0.008
  BA.UI.widthShare = (right - left - 2 * margin) / vw
  try(function() w:SetPos({ left + margin, vh * 0.03 }, "Always") end)
  try(function() w:SetSize({ right - left - 2 * margin, vh * 0.55 }, "Always") end)
end

function BA.UI.Show()
  local w = BA.UI.window
  if BA.UI.menuHidden then BA.UI.reopen = true; return end
  if w and not w.Open then
    if not BA.UI.placed then placeDefault(w); BA.UI.placed = true end
    w.Open = true
    BA.Refresh(true)
  end
end

function BA.UI.Hide()
  if BA.UI.menuHidden then BA.UI.reopen = false; return end
  if BA.UI.window and BA.UI.window.Open then BA.UI.window.Open = false end
end

local function resetContent()
  if BA.UI.content then try(function() BA.UI.content:Destroy() end) end
  BA.UI.content = BA.UI.window:AddGroup("content")
  return BA.UI.content
end

-- the game's origin resource names are ids ("DarkUrge", "Laezel"): show the names players know
local ORIGIN_NAME = { darkurge = "The Dark Urge", laezel = "Lae'zel" }
local function originLabel(o)
  return ORIGIN_NAME[BA.Norm(o)] or (tostring(o):gsub("(%l)(%u)", "%1 %2"))
end

local function describeChar(ctx)
  local parts = {}
  table.insert(parts, ctx.name or "Unnamed")
  if ctx.origin and BA.OriginKey(ctx) ~= "generic" and originLabel(ctx.origin) ~= ctx.name then
    table.insert(parts, "(" .. originLabel(ctx.origin) .. ")")
  end
  if ctx.race then table.insert(parts, "- " .. tostring(ctx.race.display)) end
  local cls = {}
  for _, c in ipairs(ctx.classes or {}) do
    table.insert(cls, c.display .. (c.sub and (" [" .. c.sub .. "]") or "") .. " " .. tostring(c.level))
  end
  if #cls > 0 then table.insert(parts, "- " .. table.concat(cls, " / ")) end
  return table.concat(parts, " ")
end

-- ctx: detection result (may be nil); entry: selected {build, reason}; analysis: BA.Analyse result
function BA.UI.Render(ctx, ranked, selectedIdx, analysis)
  if not BA.UI.window then return end
  BA.UI.ranked = ranked

  local names = {}
  for i, e in ipairs(ranked or {}) do
    names[i] = (i == 1 and "[Recommended] " or "") .. e.build.name .. "  (" .. e.build.tier .. ")"
  end
  BA.UI.combo.Options = names
  BA.UI.combo.SelectedIndex = math.max(0, (selectedIdx or 1) - 1)

  local c = resetContent()
  if not ctx then
    text(c, "No character found. Start a new game, use Withers' respec, or level up a party member.", GREY)
    return
  end

  local modeLine = "Mode: " .. ctx.mode
  if ctx.mode == "Level Up" then modeLine = modeLine .. " -> character level " .. tostring(ctx.level) end
  if ctx.mode == "Party" then modeLine = modeLine .. " (level " .. tostring(ctx.level) .. "; showing your next level)" end
  text(c, modeLine, GOLD)
  text(c, describeChar(ctx))

  local origin = BA.OriginInfo(ctx)
  if origin and origin.note and BA.OriginKey(ctx) ~= "generic" then text(c, origin.note, GREY) end

  local entry = ranked and ranked[selectedIdx or 1]
  if not entry then return end
  local b = entry.build

  c:AddSeparatorText(b.name)
  text(c, "Tier " .. b.tier .. " - " .. b.role, GOLD)
  text(c, b.why)
  text(c, "Why suggested: " .. entry.reason, GREY)

  -- What to do right now
  local step = (ctx.mode == "Party") and analysis.nextStep or analysis.step
  local stepLevel = (ctx.mode == "Party") and analysis.level + 1 or analysis.level
  c:AddSeparatorText(ctx.mode == "Party" and "NEXT LEVEL-UP" or "DO THIS NOW")
  if step then
    text(c, string.format("Level %d: take a level in %s", stepLevel, step.cls), GREEN)
    for _, p in ipairs(step.picks) do bullet(c, p, GREEN) end
  else
    text(c, "Build complete (level 12).", GREEN)
  end

  if ctx.mode == "Character Creation" or ctx.mode == "Respec" then
    bullet(c, "Race: " .. table.concat(b.races, " > ") .. "  - " .. b.raceWhy, GREEN)
    if b.raceHl then bullet(c, "Race choice (" .. b.races[1] .. "): " .. table.concat(b.raceHl, ", "), GREEN) end
    bullet(c, "Background: " .. b.background, GREEN)
    if b.deity then bullet(c, "Deity: " .. b.deity .. " (no rules effect)", GREEN) end
    local ab = {}
    for _, k in ipairs(BA.ABILITIES) do ab[#ab + 1] = k .. " " .. b.base[k] end
    bullet(c, "Point buy: " .. table.concat(ab, ", ") .. "   (+2 " .. b.plus2 .. ", +1 " .. b.plus1 .. ")", GREEN)
    bullet(c, "Skills: " .. table.concat(b.skills, ", "), GREEN)
  end

  -- Checks of current choices
  if #analysis.checks > 0 then
    c:AddSeparatorText("Your current choices")
    for _, chk in ipairs(analysis.checks) do
      bullet(c, (chk.ok and "[OK] " or "[CHANGE] ") .. chk.text, chk.ok and GREEN or RED)
    end
  end
  for _, wmsg in ipairs(analysis.warnings) do text(c, "! " .. wmsg, RED) end
  if b.note then text(c, b.note, GREY) end

  -- Full plan
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

  local g = c:AddCollapsingHeader("Gear & tips")
  text(g, "Key gear: " .. (b.gear or "-"))
  text(g, "Respec any time at camp with Withers (100 gold). The mod follows you through every level-up after a respec.", GREY)
end
