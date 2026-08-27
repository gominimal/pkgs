let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let emscripten = import "../emscripten/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let libglvnd = import "../libglvnd/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxcursor = import "../libxcursor/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxfixes = import "../libxfixes/build.ncl" in
let libxi = import "../libxi/build.ncl" in
let libxinerama = import "../libxinerama/build.ncl" in
let libxrandr = import "../libxrandr/build.ncl" in
let libxrender = import "../libxrender/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let version = "6.0" in
{
  name = "raylib",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/raysan5/raylib/archive/refs/tags/%{version}.tar.gz",
      sha256 = "2b3ee1e2120c7a0796b33062c7e9a694dd8a8caa56a96319ac8c8ecf54a90d0b",
      extract = true,
      strip_prefix = "raylib-%{version}",
    } | Source,
    base,
    emscripten, # wasm32 build of the same source, for vendor:raylib on wasm
    make,
    pkgconf,
    toolchain,
    xorgproto,
  ],

  # raylib bundles every library it needs (GLFW, glad, miniaudio, stb) under
  # src/external, so the only external surface is X11 and GL. GLFW dlopens the
  # Xrandr/Xinerama/Xcursor/Xi extensions at runtime but includes their headers
  # at compile time, so they are needed on both sides.
  runtime_deps = [
    glibc,
    libglvnd,
    libx11,
    libxcursor,
    libxext,
    libxfixes,
    libxi,
    libxinerama,
    libxrandr,
    libxrender,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libraylib.so*" } | OutputLib,
    static = { glob = "usr/lib/libraylib.a" } | OutputLib,
    web = { glob = "usr/lib/emscripten/libraylib.web.a" } | OutputLib,
    includes = { glob = "usr/include/*.h" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "raysan5",
        repo = "raylib",
      },
    } | Attrs,

  tests = {
    # No display in the sandbox, so this links rather than runs: it proves the
    # static archive and every system library raylib expects resolve.
    link_static =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc, libglvnd, libx11],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <raylib.h>\\nint main(void){ SetTraceLogLevel(LOG_NONE); return GetRandomValue(1,1) == 1 ? 0 : 1; }\\n' > t.c"],
          ["/bin/bash", "-c", "gcc t.c -o t -lraylib -lGL -lX11 -lm -lpthread -ldl -lrt"],
          ["/bin/bash", "-c", "./t"],
        ],
      } | Test,

    link_shared =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc, libglvnd, libx11],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <raylib.h>\\nint main(void){ return GetRandomValue(1,1) == 1 ? 0 : 1; }\\n' > t.c"],
          ["/bin/bash", "-c", "gcc t.c -o t -l:libraylib.so.600 -lm && ./t"],
        ],
      } | Test,
  },
} | BuildSpec
