"""Runs tools/mock_test.lua with an embedded Lua (pip install lupa)."""
import os
import lupa

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")
src = open(os.path.join(root, "tools", "mock_test.lua"), encoding="utf-8").read()
lua = lupa.LuaRuntime()
fails = lua.execute(src.replace("local ROOT = ...", 'local ROOT = "%s"' % root))
raise SystemExit(1 if fails else 0)
