let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let sed = import "../sed/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libxcrypt = import "../libxcrypt/build.ncl" in

let version = "5.0.3" in
{
  name = "screen",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/screen-%{version}.tar.gz",
      sha256 = "941c98ffecdca4bff4bbd1cd6f08fbd18967353affc46521040a999dafbd39a2",
      extract = true,
      strip_prefix = "screen-%{version}",
    } | Source,
    sed,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
    ncurses,
    libxcrypt,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    etcs = { glob = "etc/**" } | OutputData,
    screen = { glob = "usr/bin/screen*" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    screendata = { glob = "usr/share/screen/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "screen",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/screen -v",
  },
} | BuildSpec
