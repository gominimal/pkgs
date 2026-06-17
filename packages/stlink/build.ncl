let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libusb = import "../libusb/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.8.0" in
{
  name = "stlink",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/stlink-org/stlink/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cff760b5c212c2cc480f705b9ca7f3828d6b9c267950c6a547002cd0a1f5f6ac",
      extract = true,
      strip_prefix = "stlink-%{version}",
    } | Source,
    base,
    cmake,
    libusb,
    make,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    libusb,
    subsetOf gcc ["libs"],
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libstlink.so*" } | OutputLib,
    st-flash = { glob = "usr/bin/st-flash" } | OutputBin,
    st-info = { glob = "usr/bin/st-info" } | OutputBin,
    st-trace = { glob = "usr/bin/st-trace" } | OutputBin,
    st-util = { glob = "usr/bin/st-util" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/st-info --version",
  },

  attrs = {
    upstream_version = version,
    license_spdx = "BSD-3-Clause",
    source_provenance = {
      category = 'GithubRepo,
      owner = "stlink-org",
      repo = "stlink",
    },
  },
} | BuildSpec
