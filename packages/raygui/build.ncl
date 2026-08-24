let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let emscripten = import "../emscripten/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let libglvnd = import "../libglvnd/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let raylib = import "../raylib/build.ncl" in

let version = "4.0" in
{
  name = "raygui",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/raysan5/raygui/archive/refs/tags/%{version}.tar.gz",
      sha256 = "299c8fcabda68309a60dc858741b76c32d7d0fc533cdc2539a55988cee236812",
      extract = true,
      strip_prefix = "raygui-%{version}",
    } | Source,
    base,
    emscripten, # wasm32 build of the same header, for vendor:raylib on wasm
    toolchain,
  ],

  # raygui is a single header compiled against raylib's; every consumer links
  # both, so raylib rides along wherever raygui goes.
  runtime_deps = [
    glibc,
    raylib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libraygui.so*" } | OutputLib,
    static = { glob = "usr/lib/libraygui.a" } | OutputLib,
    web = { glob = "usr/lib/emscripten/libraygui.a" } | OutputLib,
    includes = { glob = "usr/include/raygui.h" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "raysan5",
        repo = "raygui",
      },
    } | Attrs,

  tests = {
    # Links rather than runs -- raygui's entry points need a GL context, and
    # there is no display in the sandbox.
    link_static =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, glibc, libglvnd, libx11, raylib],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <raylib.h>\\n#include <raygui.h>\\nint main(void){ return GuiGetStyle(DEFAULT, TEXT_SIZE) >= 0 ? 0 : 1; }\\n' > t.c"],
          ["/bin/bash", "-c", "gcc t.c -o t -lraygui -lraylib -lGL -lX11 -lm -lpthread -ldl -lrt && ./t"],
        ],
      } | Test,
  },
} | BuildSpec
