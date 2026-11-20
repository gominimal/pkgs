let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let python = import "../python/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let bash = import "../bash/build.ncl" in
let tcl = import "../tcl/build.ncl" in

let version = "5.45.4" in
{
  name = "expect",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/expect%{version}.tar.gz",
      sha256 = "49a7da83b0bdd9f46d04a04deec19c7767bb9a323e40c4781f89caf760b92c34"
    } | Source,
    # Tcl 9 port (Debian) + the rest of LFS's gcc 15 fix; see build.sh.
    { file = "debian-11-ttyname.patch" } | Local,
    { file = "debian-13-implicit-defs.patch" } | Local,
    { file = "debian-22-segfault-with-stubs.patch" } | Local,
    { file = "debian-40-tcl9.patch" } | Local,
    { file = "debian-41-uninitialized.patch" } | Local,
    { file = "expect-5.45.4-gcc15-residual.patch" } | Local,
    base,
    make,
    patch,
    python,
    toolchain,
  ],
  runtime_deps = [
    bash,
    tcl,
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**/*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'Sourceforge,
      name = "expect",
    },
    license_spdx = "NIST-PD",
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/expect -v",
    # Runs on the Tcl it was built against, and that Tcl is 9.
    tcl9 =
      {
        class = 'Standalone,
        cmds = [["/usr/bin/expect", "-c", "exit [expr {[package vsatisfies [info patchlevel] 9-] ? 0 : 3}]"]],
      } | Test,
    # spawn + expect through a pty: the channel driver the Tcl 9 port rewrote.
    spawn =
      {
        class = 'Standalone,
        cmds = [["/usr/bin/expect", "-c", "set timeout 20; spawn /usr/bin/bash -c {echo $((6*7))}; expect { 42 { exit 0 } timeout { exit 4 } eof { exit 5 } }"]],
      } | Test,
  },
} | BuildSpec
