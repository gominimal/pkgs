let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.0" in
{
  name = "libvmaf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Netflix/vmaf/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7178c4833639e6b989ecae73131d02f70735fdb3fc2c7d84bc36c9c3461d93b1",
      extract = true,
      strip_prefix = "vmaf-%{version}",
    } | Source,
    base,
    toolchain,
    meson,
    nasm,
    ninja,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/vmaf" } | OutputBin,
    libs = { glob = "usr/lib/libvmaf.so*" } | OutputLib,
    includes = { glob = "usr/include/libvmaf/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause-Patent",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Netflix",
        repo = "vmaf",
      },
    } | Attrs,
} | BuildSpec
