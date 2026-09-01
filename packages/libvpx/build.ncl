let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let perl = import "../perl/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.17.0" in
{
  name = "libvpx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/webmproject/libvpx/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "1020f184046187baa2985dbde38e0691f49c44088bca7a1842b0236c6081dc0a",
      extract = true,
      strip_prefix = "libvpx-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    nasm,
    perl,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    vpxenc = { glob = "usr/bin/vpxenc" } | OutputBin,
    vpxdec = { glob = "usr/bin/vpxdec" } | OutputBin,
    libs = { glob = "usr/lib/libvpx.so*" } | OutputLib,
    includes = { glob = "usr/include/vpx/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "webmproject",
        repo = "libvpx",
      },
    } | Attrs,
} | BuildSpec
