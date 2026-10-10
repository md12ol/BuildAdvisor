BA = BA or {}

local SETTINGS_FILE = "BuildAdvisor_settings.json"
local DETECT_INTERVAL_MS = 500
local HIGHLIGHT_INTERVAL_MS = 1000

BA.Settings = { Hotkey = "F7", AutoOpen = true, Highlight = true, ShowAll = false, FontScale = 0.75, Choices = {},
                UnsafeUiOnOldSE = false }

function BA.LoadSettings()
  local ok, raw = pcall(Ext.IO.LoadFile, SETTINGS_FILE)
  if ok and raw and raw ~= "" then
    local ok2, data = pcall(Ext.Json.Parse, raw)
    if ok2 and type(data) == "table" then
      for k, v in pairs(data) do BA.Settings[k] = v end
    end
  end
  BA.Settings.Choices = BA.Settings.Choices or {}
  -- F10 (hide UI) and F9 (photo mode) are game keys; move older saved settings to the new default
  if BA.Settings.Hotkey == "F10" or BA.Settings.Hotkey == "F9" then BA.Settings.Hotkey = "F7" end
end

function BA.SaveSettings()
  pcall(Ext.IO.SaveFile, SETTINGS_FILE, Ext.Json.Stringify(BA.Settings))
end

local function signature(ctx, buildId)
  if not ctx then return "none" end
  local p = { ctx.mode, ctx.level, ctx.name, ctx.origin, ctx.race and ctx.race.display, buildId,
              ctx.pendingClass and ctx.pendingClass.name, tostring(BA.Settings.ShowAll) }
  for _, c in ipairs(ctx.classes or {}) do p[#p + 1] = c.name .. (c.sub or "") .. c.level end
  for _, k in ipairs(BA.ABILITIES) do p[#p + 1] = ctx.abilities and ctx.abilities[k] end
  for k, v in pairs(ctx.racial or {}) do p[#p + 1] = k .. v end
  for i = 1, #p do p[i] = tostring(p[i]) end
  return table.concat(p, "|")
end

local lastSig, lastCreation
BA.Current = nil -- { ctx, build, analysis }

function BA.Refresh(force)
  local ok, ctx = pcall(BA.Detect)
  if not ok then ctx = nil; Ext.Utils.PrintWarning("[Build Advisor] detect failed: " .. tostring(ctx)) end

  -- Auto-show when a creation / respec / level-up screen appears, auto-hide when it closes.
  -- The hotkey (BA.UI.Toggle, F7 by default) still opens / closes the window at any time.
  local creation = BA.IsCreationMode(ctx)
  if creation ~= lastCreation then
    if creation then
      if BA.Settings.AutoOpen then BA.UI.Show() end
    else
      BA.HL.Run(BA.HL.Clear)
      if lastCreation ~= nil then BA.UI.Hide() end
    end
    lastCreation = creation
  end

  local ranked, idx, analysis = {}, 1, nil
  if ctx then
    ranked = BA.RankBuilds(ctx, BA.Settings.ShowAll)
    BA.UI.charKey = BA.Norm(ctx.origin) .. "|" .. BA.Norm(ctx.name)
    local chosen = BA.Settings.Choices[BA.UI.charKey]
    if chosen and not BA.BuildById[chosen] then chosen = nil end
    if chosen then
      local found = false
      for i, e in ipairs(ranked) do if e.build.id == chosen then idx = i; found = true end end
      if not found then table.insert(ranked, { build = BA.BuildById[chosen], reason = "Your choice" }); idx = #ranked end
    end
    if ranked[idx] then analysis = BA.Analyse(ctx, ranked[idx].build) end
  end
  BA.Current = { ctx = ctx, build = ranked[idx] and ranked[idx].build, analysis = analysis }

  local sig = signature(ctx, BA.Current.build and BA.Current.build.id)
  if force or sig ~= lastSig then
    lastSig = sig
    local okR, err = pcall(BA.UI.Render, ctx, ranked, idx, analysis or { checks = {}, warnings = {} })
    if not okR then Ext.Utils.PrintError("[Build Advisor] render failed: " .. tostring(err)) end
  end
end

local lastDetect, lastHighlight, lastMenu = 0, 0, 0
local function onTick()
  local now = Ext.Utils.MonotonicTime()
  -- the advisor window steps aside while the game's pause menu is open (read in the deferred UI update)
  if now - lastMenu >= 100 then lastMenu = now; BA.HL.Run(BA.HL.CheckMenu) end
  pcall(BA.UI.SetMenuHidden, BA.HL.menuOpen == true)
  if now - lastDetect >= DETECT_INTERVAL_MS then
    lastDetect = now
    BA.Refresh(false)
  end
  if BA.Settings.Highlight and now - lastHighlight >= HIGHLIGHT_INTERVAL_MS then
    lastHighlight = now
    local cur = BA.Current
    if cur and cur.analysis and BA.IsCreationMode(cur.ctx) then
      local opts = { onlyPlannedAbilities = cur.ctx.mode == "Level Up" }
      local a = cur.analysis
      BA.HL.Run(function()
        local ok, err = pcall(BA.HL.Apply, a.highlight, a.abilityPlan, a.skillPlan, opts)
        if not ok then Ext.Utils.PrintWarning("[Build Advisor] highlight failed: " .. tostring(err)) end
      end)
    end
  end
end

local function onKey(e)
  if e.Event == "KeyDown" and not e.Repeat and tostring(e.Key) == BA.Settings.Hotkey then
    BA.UI.Toggle()
  end
end

local initialized = false
local function init()
  if initialized then return end
  BA.LoadSettings()
  BA.UI.Init()
  initialized = true
  Ext.Events.Tick:Subscribe(onTick)
  Ext.Events.KeyInput:Subscribe(onKey)
  Ext.Utils.Print("[Build Advisor] loaded - press " .. BA.Settings.Hotkey .. " to toggle the advisor.")
end

-- IMGUI is ready once the client has finished loading the session; also init on reset (console "reset").
Ext.Events.SessionLoaded:Subscribe(init)
Ext.Events.ResetCompleted:Subscribe(init)
-- Character creation at the main menu happens before SessionLoaded on some versions
Ext.Events.Tick:Subscribe(function() if not initialized then pcall(init) end end)

-- Console helpers:  !ba_dump   !ba_toggle   !ba_hotkey F7
Ext.RegisterConsoleCommand("ba_dump", function()
  local ok, ctx = pcall(BA.Detect)
  _D(ok and ctx or ("detect error: " .. tostring(ctx)))
  if BA.HL.ms then Ext.Utils.Print(string.format("[Build Advisor] last menu pass: %s ms, %s nodes, %s outlines", tostring(BA.HL.ms), tostring(BA.HL.nodes), tostring(BA.HL.outlines))) end
end)
Ext.RegisterConsoleCommand("ba_toggle", function() BA.UI.Toggle() end)
Ext.RegisterConsoleCommand("ba_hotkey", function(_, key)
  if key and key ~= "" then BA.Settings.Hotkey = key:upper(); BA.SaveSettings(); Ext.Utils.Print("[Build Advisor] hotkey = " .. BA.Settings.Hotkey) end
end)
