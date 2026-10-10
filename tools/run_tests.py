"""Runs the offline tests with an embedded Lua (pip install lupa).

  python tools/run_tests.py            tools/mock_test.lua, the UI-thread gate (tools/ui_gate_test.lua) and the
                                       meta.lsx Description check
  python tools/run_tests.py --mutate   the gate with its guard removed and broken descriptions (patched in memory):
                                       must go red
"""
import html
import os
import re
import sys

import lupa

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")


def lua_file(name):
    with open(os.path.join(root, "tools", name), encoding="utf-8") as f:
        return f.read()


def mock_test():
    lua = lupa.LuaRuntime()
    return lua.execute(lua_file("mock_test.lua").replace("local ROOT = ...", 'local ROOT = "%s"' % root))


def gate(defer, unsafe, patches):
    lua = lupa.LuaRuntime()
    fn = lua.eval("function(...) return load(...) end")(lua_file("ui_gate_test.lua"), "@ui_gate_test.lua")
    lua_patches = lua.table_from({k: lua.table_from([lua.table_from(p) for p in v]) for k, v in patches.items()})
    return fn(root, defer, unsafe, lua_patches)


def gate_failures(patches=None):
    """Old Script Extender: the tree is never touched, one log line names v33, the advisor window still renders.
    Ext.UI.Defer present: every touch is inside the deferred callback and the walk reaches the menu labels.
    Old Script Extender with UnsafeUiOnOldSE: the walk runs."""
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
    return fails, r.ticks


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
]


def main():
    if "--mutate" in sys.argv:
        bad = 0
        for desc, patches in MUTATIONS:
            fails, _ = gate_failures(patches)
            ok = bool(fails)
            bad += not ok
            print(f"[{'OK' if ok else 'BAD'}] {desc}\n      " + ("; ".join(fails[:2]) if fails else "still green"))
        for desc, break_it in DESCRIPTION_MUTATIONS:
            fails = description_failures(break_it(meta_description()))
            ok = bool(fails)
            bad += not ok
            print(f"[{'OK' if ok else 'BAD'}] {desc}\n      " + ("; ".join(fails[:2]) if fails else "still green"))
        total = len(MUTATIONS) + len(DESCRIPTION_MUTATIONS)
        print(f"\n{total - bad}/{total} mutations went red")
        return 1 if bad or not MUTATIONS else 0
    failed = bool(mock_test())
    fails, ticks = gate_failures()
    for f in fails:
        print("FAIL: " + f)
    print(f"UI-thread gate: 3 scenarios x {ticks} ticks, {len(fails)} failures")
    desc = meta_description()
    desc_fails = description_failures(desc)
    for f in desc_fails:
        print("FAIL: " + f)
    print(f"meta.lsx Description: {len(desc)} characters, {len(desc_fails)} failures")
    return 1 if failed or fails or desc_fails or ticks == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
