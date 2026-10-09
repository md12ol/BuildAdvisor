"""Runs the offline tests with an embedded Lua (pip install lupa).

  python tools/run_tests.py            tools/mock_test.lua, then the UI-thread gate (tools/ui_gate_test.lua)
  python tools/run_tests.py --mutate   the gate with its guard removed (patched in memory): must go red
"""
import os
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
        print(f"\n{len(MUTATIONS) - bad}/{len(MUTATIONS)} mutations went red")
        return 1 if bad or not MUTATIONS else 0
    failed = bool(mock_test())
    fails, ticks = gate_failures()
    for f in fails:
        print("FAIL: " + f)
    print(f"UI-thread gate: 3 scenarios x {ticks} ticks, {len(fails)} failures")
    return 1 if failed or fails or ticks == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
