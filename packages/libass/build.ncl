let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let harfbuzz = import "../harfbuzz/build.ncl" in

let version = "0.17.5" in
{
  name = "libass",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libass/libass/releases/download/%{version}/libass-%{version}.tar.gz",
      sha256 = "caab4b993dd7be6187c55623b789ed75dddefea6e65938af134637c732fe094a",
      extract = true,
      strip_prefix = "libass-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    fontconfig,
    freetype,
    fribidi,
    glibc,
    harfbuzz,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libass.so*" } | OutputLib,
    includes = { glob = "usr/include/ass/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <ass/ass.h>\n#include <stdio.h>\nint main() { ASS_Library* s = ass_library_init(); if (s) { printf(\"ok\\n\"); ass_library_done(s); return 0; } return 1; }' > test.c"],
          ["/bin/gcc", "test.c", "-lass", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^ok$'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libass",
        repo = "libass",
      },
    } | Attrs,
} | BuildSpec
