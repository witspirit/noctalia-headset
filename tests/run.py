"""Run the widget's Lua-compatible logic against a fake Noctalia/audio host.

Uses the system Lua 5.4 or 5.5 library for behavioral checks.
No audio commands are executed. Run from any working directory.
"""

import ctypes
import ctypes.util
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
library = next(
    (path for name in ("lua-5.4", "lua5.4", "lua-5.5", "lua5.5")
     if (path := ctypes.util.find_library(name))),
    None,
)
if not library:
    raise SystemExit("Install the Lua 5.4 or 5.5 shared library to run these tests.")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
open_libraries = getattr(lua, "luaL_openlibs", None)
if open_libraries:
    open_libraries.argtypes = [ctypes.c_void_p]
else:
    # Lua 5.5 defines luaL_openlibs as a macro for this call.
    lua.luaL_openselectedlibs.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    def open_libraries(state):
        lua.luaL_openselectedlibs(state, -1, 0)
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
    open_libraries(state)
    status = lua.luaL_loadfilex(state, b"tests/widget_test.lua", None)
    if status == 0:
        status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
    if status:
        raise SystemExit(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
