let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gperf = import "../gperf/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.2.15" in
{
  name = "eudev",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/eudev-project/eudev/releases/download/v%{version}/eudev-%{version}.tar.gz",
      sha256 = "eb69809fc0d1187f2463ab2149c53aa9f42a78e59f14ebea68eae6cb6b4fc1c3",
      extract = true,
      strip_prefix = "eudev-%{version}",
    } | Source,
    base,
    gperf,
    make,
    # 3.2.15's shipped configure aborts with "pkg-config not found" without
    # it (pkgs#1093); 3.2.14's did not.
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libudev.so*" } | OutputLib,
    includes = { glob = "usr/include/libudev.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/libudev.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "eudev-project",
        repo = "eudev",
      },
    } | Attrs,
} | BuildSpec
