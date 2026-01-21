let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let bzip2 = import "../bzip2/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let xz = import "../xz/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.194" in
{
  name = "elfutils",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/elfutils-%{version}.tar.bz2",
      sha256 = "09e2ff033d39baa8b388a2d7fbc5390bfde99ae3b7c67c7daaf7433fbcf0f01e",
    } | Source,
    base,
    m4,
    make,
    toolchain,
    pkgconf,
  ],
  runtime_deps = [
    bzip2,
    glibc,
    zlib,
    xz,
    zstd,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "elfutils",
    } | Attrs,

  tests = {
    readelf_sections =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo 'int main() { return 42; }' > prog.c"],
          ["/bin/gcc", "prog.c", "-o", "prog"],
          ["/bin/bash", "-c", "readelf -S prog | grep -q '\\.text'"],
          ["/bin/bash", "-c", "readelf -S prog | grep -q '\\.data'"],
          ["/bin/bash", "-c", "readelf -S prog | grep -q '\\.bss'"],
        ],
      } | Test,
  },
} | BuildSpec
