let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.0.29" in
{
  name = "libusb",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libusb/libusb/releases/download/v%{version}/libusb-%{version}.tar.bz2",
      sha256 = "5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85",
      extract = true,
      strip_prefix = "libusb-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libusb-1.0.so*" } | OutputLib,
    headers = { glob = "usr/include/libusb-1.0/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libusb-1.0.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "LGPL-2.1-or-later",
    source_provenance = {
      category = 'GithubRepo,
      owner = "libusb",
      repo = "libusb",
    },
  },
} | BuildSpec
