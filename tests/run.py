"""Run the widget's Lua-compatible logic against a fake Noctalia/audio host.

Uses system Lua 5.4, not Luau: this verifies behavior, not Noctalia integration.
No audio commands are executed. Run from any working directory.
"""

import ctypes
import ctypes.util
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
library = ctypes.util.find_library("lua-5.4") or ctypes.util.find_library("lua5.4")
if not library:
    raise SystemExit("Install the Lua 5.4 shared library to run these tests.")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                         ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    raise SystemExit("Could not allocate Lua state")
os.chdir(root)
try:
    lua.luaL_openlibs(state)
    status = lua.luaL_loadfilex(state, b"tests/widget_test.lua", None)
    if status == 0:
        status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
    if status:
        raise SystemExit(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
