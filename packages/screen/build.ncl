let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let sed = import "../sed/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libxcrypt = import "../libxcrypt/build.ncl" in

let version = "5.0.1" in
{
  name = "screen",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/screen-%{version}.tar.gz",
      sha256 = "2dae36f4db379ffcd14b691596ba6ec18ac3a9e22bc47ac239789ab58409869d",
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
      source_provenance = {
        category = 'GnuProject,
        name = "screen",
      },
    } | Attrs,
} | BuildSpec
