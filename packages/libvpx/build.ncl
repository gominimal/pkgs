let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let perl = import "../perl/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.16.0" in
{
  name = "libvpx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/webmproject/libvpx/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7a479a3c66b9f5d5542a4c6a1b7d3768a983b1e5c14c60a9396edc9b649e015c",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "webmproject",
        repo = "libvpx",
      },
    } | Attrs,
} | BuildSpec
