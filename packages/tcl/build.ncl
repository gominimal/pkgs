let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.6.18" in
{
  name = "tcl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tcl%{version}-src.tar.gz",
      sha256 = "14f9af32b1767ff718477a8f974ad03c34341097e6b43f4ce54644ee974e268e"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    "tclsh8.6" = { glob = "usr/bin/tclsh8.6" } | OutputBin,
    libs = { glob = "usr/lib/**/*.{a,so*}" } | OutputLib,

    datas = { glob = "usr/lib/**/{tclIndex,*.c,*.tm,*.uuid,*.tcl,*.sh,*.enc,*.msg}" } | OutputData,
    tzdata = { glob = "usr/lib/tcl*/tzdata/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "TCL",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tcltk",
        repo = "tcl",
      },
    } | Attrs,
} | BuildSpec
