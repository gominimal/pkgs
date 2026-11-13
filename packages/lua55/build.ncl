let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

# Lua's series is its MINOR component, and the series are separate, mutually
# incompatible libraries that install side by side -- hence one package per
# series rather than a single `lua` (see ../lua54/build.ncl). A bump must stay
# inside the series: 5.6 would be a different library, not an upgrade. Odin's
# vendor:lua/5.5 bindings are the consumer that brought this series in.
let version = "5.5.1" in
let abi = "5.5" in
{
  name = "lua55",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/lua-%{version}.tar.gz",
      sha256 = "1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce",
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
          # -l:liblua5.5.a, not -llua5.5: with both in the same directory ld
          # picks the shared object, which would make this a duplicate of
          # link_shared and leave the archive -- the artifact odin vendors --
          # untested.
          ["/bin/bash", "-c", "gcc t.c -o t -l:liblua%{abi}.a -lm -ldl && ./t"],
        ],
      } | Test,

    # `system:lua5.5` is what Odin's vendor bindings link against off amd64, so
    # the plain -l name has to resolve to the shared library.
    link_shared =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc],
        cmds = [
          # Deliberately only newstate/close, the same check as lua51..lua54.
          ["/bin/bash", "-c", "printf '#include <lua%{abi}/lua.h>\\n#include <lua%{abi}/lauxlib.h>\\nint main(void){ lua_State *L = luaL_newstate(); if (!L) return 1; lua_close(L); return 0; }\\n' > t.c"],
          ["/bin/bash", "-c", "gcc t.c -o t -l:liblua%{abi}.so -lm && ./t"],
        ],
      } | Test,
  },
} | BuildSpec
