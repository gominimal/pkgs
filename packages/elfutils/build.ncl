let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let xz = import "../xz/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.195" in
{
  name = "elfutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/elfutils-%{version}.tar.bz2",
      sha256 = "37629fdf7f1f3dc2818e138fca2b8094177d6c2d0f701d3bb650a561218dc026",
    } | Source,
    base,
    m4,
    make,
    toolchain,
    pkgconf,
  ],
  runtime_deps = [
    bash, # /usr/bin/eu-make-debug-archive depends on /bin/sh
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

    # libelf.pc / libdw.pc — installed by `make install` but previously
    # uncaptured, so any pkg-config consumer (e.g. libbpf's
    # `Requires.private: libelf`, resolved by dwarves) failed to find them.
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GFDL-1.3-invariants-only AND GPL-2.0-only AND GPL-3.0-only)",
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
