let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.15.0" in
{
  name = "freetype",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/freetype/freetype-2.15.0.tar.xz
      url = "gs://minimal-staging-archives/freetype-%{version}.tar.xz",
      sha256 = "93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5",
      extract = true,
      strip_prefix = "freetype-%{version}",
    } | Source,
    base,
    toolchain,
    sed,
    make,
  ],
  runtime_deps = [
    glibc,
    libpng,
    # configure auto-detects bzip2 (the build closure has it); libfreetype.so.6
    # then NEEDS libbz2.so.1.0 (smoke-test finding: linking -lharfbuzz failed).
    bzip2,
  ],

  cmd = "./build.sh",

  outputs = {
    freetype-config = { glob = "usr/bin/freetype-config", allow_missing_interpreter = true } | OutputBin,

    libs = { glob = "usr/lib/libfreetype*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
  attrs.license_spdx = "FTL OR GPL-2.0-or-later",

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/usr/bin/bash", "-c", "/usr/bin/freetype-config --version"]],
      } | Test,
  },
} | BuildSpec
