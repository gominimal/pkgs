let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "9.1.0" in
# tclsh, libtcl and the script library are named for the major.minor series
# (tclsh9.1, libtcl9.1.so, /usr/lib/tcl9.1).
let api = std.string.join "." (std.array.slice 0 2 (std.string.split "." version)) in
{
  name = "tcl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tcl%{version}-src.tar.gz",
      sha256 = "536c45543f64d6eb11832d97ba3494aacff046fbc5040273bd55258d0e448ff1"
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
    tclsh_versioned = { glob = "usr/bin/tclsh%{api}" } | OutputBin,
    libs = { glob = "usr/lib/**/*.{a,so*}" } | OutputLib,

    datas = { glob = "usr/lib/**/{tclIndex,*.c,*.tm,*.uuid,*.tcl,*.sh,*.enc,*.msg,*.gz}" } | OutputData,
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

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [["/bin/bash", "-c", "echo 'puts [expr {6*7}]' | /usr/bin/tclsh%{api} | grep -qx 42"]],
      } | Test,
  },
} | BuildSpec
