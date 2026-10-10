-- The window's Gear part: the build's gear sets, read at runtime from Loot Advisor when it is loaded, so Build Advisor
-- ships no item data of its own.

BA = BA or {}
BA.Gear = {}

BA.Gear.LA_UUID = "af37374f-f532-421a-b778-a24e17255c7e"
BA.Gear.SETS = 3
BA.Gear.SPOILER = "Gear from Loot Advisor (spoilers: item names)"
BA.Gear.REF = "Where to find them and live tracking: Loot Advisor (F6) and its Sets page."
BA.Gear.REF_NO_SETS = "Loot Advisor has no gear sets for this build; it recommends the closest build's items (F6)."
BA.Gear.REF_MISSING = "Install Loot Advisor for gear sets."

local function try(f, ...)
  local ok, r = pcall(f, ...)
  if ok then return r end
  return nil
end

-- Loot Advisor's API table (LA.Api), or nil when the mod is not loaded or too old to have one
function BA.Gear.Api()
  if not try(function() return Ext.Mod.IsModLoaded(BA.Gear.LA_UUID) end) then return nil end
  local api = try(function() return Mods.LootAdvisor.LA.Api end)
  if type(api) == "table" and type(api.GearSets) == "function" then return api end
  return nil
end

local function itemLine(it)
  local s = tostring(it.slotName or it.slot) .. ": " .. tostring(it.name)
  if it.owned then s = s .. " (you have it)"
  elseif it.onlyOwned then s = s .. " (only if you already have it)" end
  return s
end

-- What the Gear part shows. Pure: tested offline with a stand-in api.
-- -> { sets = { { title, acts = { { title = "Act 1: Best overall", items = { "Main hand: ..." } } } } },
--      header = the spoiler note (nil without sets), ref = the line pointing to Loot Advisor }
function BA.Gear.Outline(ctx, build, api)
  if not api then return { sets = {}, ref = BA.Gear.REF_MISSING } end
  local data = build and try(api.GearSets, BA.OriginKey(ctx), build.id, BA.Gear.SETS)
  local out = { sets = {} }
  for rank = 1, BA.Gear.SETS do
    local acts, names, seen = {}, {}, {}
    for act = 1, 3 do
      local a = type(data) == "table" and type(data.sets) == "table" and data.sets[rank] and data.sets[rank][act]
      if type(a) == "table" and type(a.items) == "table" and #a.items > 0 then
        local lines = {}
        for _, it in ipairs(a.items) do lines[#lines + 1] = itemLine(it) end
        acts[#acts + 1] = { title = "Act " .. act .. (a.name and (": " .. a.name) or ""), items = lines }
        if a.name and not seen[a.name] then seen[a.name] = true; names[#names + 1] = a.name end
      end
    end
    if #acts > 0 then
      local title = "Gear set " .. rank .. (#names > 0 and (": " .. table.concat(names, " / ")) or "")
      out.sets[#out.sets + 1] = { title = title, acts = acts }
    end
  end
  if #out.sets == 0 then out.ref = BA.Gear.REF_NO_SETS; return out end
  out.header = BA.Gear.SPOILER
  out.ref = BA.Gear.REF
  return out
end
