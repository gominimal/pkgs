let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let cmake = import "../cmake/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.19.2" in
{
  name = "patchelf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/NixOS/patchelf/archive/refs/tags/%{version}.tar.gz",
      sha256 = "05e674fcc89ef3ffbd851266d063f45f13bd16facec9839a54d0095b930c6f07",
      extract = true,
      strip_prefix = "patchelf-%{version}",
    } | Source,
    base,
    cmake,
    meson,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    patchelf = { glob = "usr/bin/patchelf" } | OutputBin,
    man = { glob = "usr/share/man/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "NixOS",
        repo = "patchelf",
      },
    } | Attrs,
} | BuildSpec
