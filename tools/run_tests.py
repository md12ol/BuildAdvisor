"""Runs the offline tests with an embedded Lua (pip install lupa).

  python tools/run_tests.py            tools/mock_test.lua, the UI-thread gate (tools/ui_gate_test.lua) and the
                                       meta.lsx Description check
  python tools/run_tests.py --mutate   the gate with its guard removed, the mock test on a patched copy of the mod's
                                       Lua and broken descriptions: must go red
"""
import html
import os
import re
import shutil
import sys
import tempfile

import lupa

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")


def lua_file(name):
    with open(os.path.join(root, "tools", name), encoding="utf-8") as f:
        return f.read()


def mock_test(mod_root=None, quiet=False):
    lua = lupa.LuaRuntime()
    if quiet:
        lua.execute("print = function() end")
    return lua.execute(lua_file("mock_test.lua").replace("local ROOT = ...", 'local ROOT = "%s"' % (mod_root or root)))


LUA_REL = ("BuildAdvisor", "Mods", "BuildAdvisor", "ScriptExtender", "Lua")


def mock_failures(patches):
    """tools/mock_test.lua on a copy of the mod's Lua with the patches applied; returns its failure count."""
    tmp = tempfile.mkdtemp(prefix="ba_mut_")
    try:
        lua_dir = os.path.join(tmp, *LUA_REL)
        shutil.copytree(os.path.join(root, *LUA_REL), lua_dir)
        for name, subs in patches.items():
            path = next(os.path.join(d, name) for d, _, fs in os.walk(lua_dir) if name in fs)
            src = open(path, encoding="utf-8", newline="").read()
            for old, new in subs:
                if old not in src:
                    raise RuntimeError(f"mutation target not found in {name}: {old[:60]}")
                src = src.replace(old, new)
            open(path, "w", encoding="utf-8", newline="").write(src)
        return mock_test(tmp.replace("\\", "/"), quiet=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# game widgets the advisor window steps aside for (x:Name of the XAML page): the pause menu, the message box
# (MessageBox.xaml: confirmations such as the respec warning) and its controller version
MENU_WIDGETS = [("GameMenu", "pause menu"), ("Dialog_box", "message box"), ("MessageBox_c", "controller message box")]


def gate(defer, unsafe, patches, menu=None):
    lua = lupa.LuaRuntime()
    fn = lua.eval("function(...) return load(...) end")(lua_file("ui_gate_test.lua"), "@ui_gate_test.lua")
    lua_patches = lua.table_from({k: lua.table_from([lua.table_from(p) for p in v]) for k, v in patches.items()})
    return fn(root, defer, unsafe, lua_patches, menu)


def gate_failures(patches=None):
    """Old Script Extender: the tree is never touched, one log line names v33, the advisor window still renders.
    Ext.UI.Defer present: every touch is inside the deferred callback and the walk reaches the menu labels.
    Old Script Extender with UnsafeUiOnOldSE: the walk runs.
    The game's pause menu or a message box (a confirmation) open (Ext.UI.Defer present): the window is closed under
    it, the hotkey there does not open it, and it comes back when it closes; old Script Extender: the menu is not
    looked for (no touches)."""
    patches = patches or {}
    fails = []
    r = gate(False, False, patches)
    if r.touches != 0:
        fails.append(f"no Ext.UI.Defer: the UI tree was touched {r.touches} times (must be 0)")
    notes = [p for p in r.prints.values() if "v33" in p]
    if len(notes) != 1:
        fails.append(f"no Ext.UI.Defer: {len(notes)} log lines name Script Extender v33 (want exactly 1)")
    if r.renders == 0:
        fails.append("no Ext.UI.Defer: the advisor window never rendered")
    r = gate(True, False, patches)
    if r.outside != 0:
        fails.append(f"Ext.UI.Defer present: {r.outside} UI tree touches outside the deferred callback (must be 0)")
    if r.labels == 0:
        fails.append("Ext.UI.Defer present: the highlighter never reached a menu label")
    r = gate(False, True, patches)
    if r.labels == 0:
        fails.append("no Ext.UI.Defer, UnsafeUiOnOldSE = true: the highlighter never reached a menu label")
    ticks = r.ticks
    for widget, what in MENU_WIDGETS:
        r = gate(True, False, patches, menu=widget)
        if r.outside != 0:
            fails.append(f"{what}: {r.outside} UI tree touches outside the deferred callback (must be 0)")
        if not r.openBefore:
            fails.append(f"{what}: the advisor window was not open before it (nothing checked)")
        if not r.hiddenInMenu:
            fails.append(f"{what} open: the advisor window stays drawn over it")
        if r.openAfterKeys:
            fails.append(f"{what} open: the hotkey opened the window over it")
        if not r.reopened:
            fails.append(f"{what} closed: the advisor window did not come back")
    r = gate(False, False, patches, menu="GameMenu")
    if r.touches != 0:
        fails.append(f"no Ext.UI.Defer, pause menu open: the UI tree was touched {r.touches} times (must be 0)")
    return fails, ticks


META_DESCRIPTION_MAX = 250   # Larian's Toolkit (mod.io publishing) caps the mod description at 250 characters


def meta_description():
    with open(os.path.join(root, "BuildAdvisor", "Mods", "BuildAdvisor", "meta.lsx"), encoding="utf-8") as f:
        m = re.search(r'id="Description" type="LSString" value="([^"]*)"', f.read())
    return html.unescape(m.group(1)) if m else ""


def description_failures(text):
    """meta.lsx Description fits the Toolkit's 250 characters and names Script Extender."""
    fails = []
    if not text:
        fails.append("meta.lsx has no Description")
    if len(text) > META_DESCRIPTION_MAX:
        fails.append(f"meta.lsx Description is {len(text)} characters (the Toolkit keeps {META_DESCRIPTION_MAX})")
    if "Script Extender" not in text:
        fails.append("meta.lsx Description does not say it needs Script Extender")
    return fails


# tools/mock_test.lua must report failures with these
MOCK_MUTATIONS = [
    ("Highlighter.lua: a long point-buy bracket keeps the full name (runs under the row's - button)",
     {"Highlighter.lua": [("if #t > ABILITY_TEXT_MAX and ABILITY_KEY[name] then", "if false then")]}),
    ("Highlighter.lua: a row under the game's short name is not found again (never updated or restored)",
     {"Highlighter.lua": [("bare == BA.Norm(name) or bare == BA.Norm(ABILITY_KEY[name] or name)",
                           "bare == BA.Norm(name)")]}),
    ("Highlighter.lua: a loca handle with its version (h...;1) is looked up as is (Bless not ringed)",
     {"Highlighter.lua": [('local t = try(Ext.Loca.GetTranslatedString, (h:gsub(";.*$", "")))',
                           "local t = try(Ext.Loca.GetTranslatedString, h)")]}),
    ("Highlighter.lua: spell icons only read the list item (replacement slots, unreadable items not ringed)",
     {"Highlighter.lua": [("local vm = iconOwnSpell(border)", "local vm = nil")]}),
    ("Highlighter.lua: a rebuilt list item at an address read empty before waits for the retry pass",
     {"Highlighter.lua": [("unreadableDC[key] ~= shape or ", "")]}),
    ("Highlighter.lua: a spell id without stats names nothing (Guiding Bolt not ringed)",
     {"Highlighter.lua": [("        add(idStem(v))", "        add(nil)")]}),
    ("Highlighter.lua: a container variant does not name its container",
     {"Highlighter.lua": [("          add(statEntry(e.container) and statEntry(e.container).name)", "")]}),
]

DESCRIPTION_MUTATIONS = [
    ("meta.lsx Description over the Toolkit's 250 characters", lambda d: d + " " + "x" * META_DESCRIPTION_MAX),
    ("meta.lsx Description without the Script Extender line", lambda d: d.replace("Script Extender", "")),
]

MUTATIONS = [
    ("Highlighter.lua BA.HL.Run: no Ext.UI.Defer -> runs the UI code anyway (gate removed)",
     {"Highlighter.lua": [("if BA.Settings and BA.Settings.UnsafeUiOnOldSE == true then", "if true then")]}),
    ("Highlighter.lua BA.HL.Run: Ext.UI.Defer present but the code runs straight from the tick",
     {"Highlighter.lua": [("defer(function() pcall(fn) end)", "pcall(fn)")]}),
    ("Main.lua: the highlight pass called straight from the tick again",
     {"Main.lua": [("BA.HL.Run(function()", "pcall(function()")]}),
    ("Highlighter.lua: the pause menu widget is not recognised",
     {"Highlighter.lua": [("BA.HL.PAUSE_WIDGETS = { GameMenu = true,", "BA.HL.PAUSE_WIDGETS = { GameMenuX = true,")]}),
    ("Highlighter.lua: the game's message box is not recognised",
     {"Highlighter.lua": [("Dialog_box = true, MessageBox_c = true }", "MessageBox_c = true }")]}),
    ("Highlighter.lua: the controller message box is not recognised",
     {"Highlighter.lua": [("Dialog_box = true, MessageBox_c = true }", "Dialog_box = true }")]}),
    ("Main.lua: the pause menu read straight from the tick",
     {"Main.lua": [("BA.HL.Run(BA.HL.CheckMenu)", "pcall(BA.HL.CheckMenu)")]}),
    ("Window.lua: the window is not reopened after the pause menu",
     {"Window.lua": [("  elseif BA.UI.reopen then", "  elseif false then")]}),
    ("Window.lua: the hotkey opens the window over the pause menu",
     {"Window.lua": [("  if BA.UI.menuHidden then", "  if false then")]}),
]


def main():
    if "--mutate" in sys.argv:
        bad = 0
        for desc, patches in MUTATIONS:
            fails, _ = gate_failures(patches)
            ok = bool(fails)
            bad += not ok
            print(f"[{'OK' if ok else 'BAD'}] {desc}\n      " + ("; ".join(fails[:2]) if fails else "still green"))
        for desc, patches in MOCK_MUTATIONS:
            n = mock_failures(patches)
            bad += not n
            print(f"[{'OK' if n else 'BAD'}] {desc}\n      " + (f"mock test: {n} failures" if n else "still green"))
        for desc, break_it in DESCRIPTION_MUTATIONS:
            fails = description_failures(break_it(meta_description()))
            ok = bool(fails)
            bad += not ok
            print(f"[{'OK' if ok else 'BAD'}] {desc}\n      " + ("; ".join(fails[:2]) if fails else "still green"))
        total = len(MUTATIONS) + len(MOCK_MUTATIONS) + len(DESCRIPTION_MUTATIONS)
        print(f"\n{total - bad}/{total} mutations went red")
        return 1 if bad or not MUTATIONS else 0
    failed = bool(mock_test())
    fails, ticks = gate_failures()
    for f in fails:
        print("FAIL: " + f)
    print(f"UI-thread gate: {4 + len(MENU_WIDGETS)} scenarios x {ticks} ticks, {len(fails)} failures")
    desc = meta_description()
    desc_fails = description_failures(desc)
    for f in desc_fails:
        print("FAIL: " + f)
    print(f"meta.lsx Description: {len(desc)} characters, {len(desc_fails)} failures")
    return 1 if failed or fails or desc_fails or ticks == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
