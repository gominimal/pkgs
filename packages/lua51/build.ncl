let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

# Lua's series is its MINOR component, and the series are separate, mutually
# incompatible libraries that install side by side -- hence one package per
# series rather than a single `lua`. 5.1, 5.2 and 5.3 are closed and the
# versions here are their final releases; only 5.4 still receives them. A bump
# must stay inside the series: 5.5 is a different library, not an upgrade.
let version = "5.1.5" in
let abi = "5.1" in
{
  name = "lua51",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/lua-%{version}.tar.gz",
      sha256 = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333",
      extract = true,
      strip_prefix = "lua-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include abi,
  },

  outputs = {
    libs = { glob = "usr/lib/liblua%{abi}.so*" } | OutputLib,
    static = { glob = "usr/lib/liblua%{abi}.a" } | OutputLib,
    includes = { glob = "usr/include/lua%{abi}/*.h*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,

  tests = {
    link_static =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <lua%{abi}/lua.h>\\n#include <lua%{abi}/lauxlib.h>\\n#include <lua%{abi}/lualib.h>\\nint main(void){ lua_State *L = luaL_newstate(); luaL_openlibs(L); int rc = luaL_dostring(L, \"x = 1 + 1\"); lua_close(L); return rc; }\\n' > t.c"],
          # -l:liblua5.4.a, not -llua5.4: with both in the same directory ld
          # picks the shared object, which would make this a duplicate of
          # link_shared and leave the archive -- the artifact odin vendors --
          # untested.
          ["/bin/bash", "-c", "gcc t.c -o t -l:liblua%{abi}.a -lm -ldl && ./t"],
        ],
      } | Test,

    # `system:lua5.4` is what Odin's vendor bindings link against off amd64, so
    # the plain -l name has to resolve to the shared library.
    link_shared =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc],
        cmds = [
          # Deliberately only newstate/close: this has to compile against 5.1
          # through 5.4, and lua_version arrived in 5.2.
          ["/bin/bash", "-c", "printf '#include <lua%{abi}/lua.h>\\n#include <lua%{abi}/lauxlib.h>\\nint main(void){ lua_State *L = luaL_newstate(); if (!L) return 1; lua_close(L); return 0; }\\n' > t.c"],
          ["/bin/bash", "-c", "gcc t.c -o t -l:liblua%{abi}.so -lm && ./t"],
        ],
      } | Test,
  },
} | BuildSpec
