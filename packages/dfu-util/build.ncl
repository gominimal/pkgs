let { standaloneTest, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libusb = import "../libusb/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.11" in
{
  name = "dfu-util",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://dfu-util.sourceforge.net/releases/dfu-util-%{version}.tar.gz",
      sha256 = "b4b53ba21a82ef7e3d4c47df2952adf5fa494f499b6b0b57c58c5d04ae8ff19e",
      extract = true,
      strip_prefix = "dfu-util-%{version}",
    } | Source,
    base,
    libusb,
    make,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    libusb,
  ],

  cmd = "./build.sh",

  outputs = {
    dfu-prefix = { glob = "usr/bin/dfu-prefix" } | OutputBin,
    dfu-suffix = { glob = "usr/bin/dfu-suffix" } | OutputBin,
    dfu-util = { glob = "usr/bin/dfu-util" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/dfu-util --version",
  },

  attrs = {
    upstream_version = version,
    license_spdx = "GPL-2.0-only",
  },
} | BuildSpec
