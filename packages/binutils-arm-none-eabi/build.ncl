let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.43.1" in
{
  name = "binutils-arm-none-eabi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/binutils/binutils-%{version}.tar.xz",
      sha256 = "13f74202a3c4c51118b797a39ea4200d3f6cfbe224da6d1d95bb938480132dfd"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
    subsetOf gcc ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/arm-none-eabi-*" } | OutputBin,
    target_libs = { glob = "usr/arm-none-eabi/lib/**" } | OutputData,
    ldscripts = { glob = "usr/arm-none-eabi/lib/ldscripts/*" } | OutputData,
    target_bin = { glob = "usr/arm-none-eabi/bin/*" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "binutils",
      },
    } | Attrs,
} | BuildSpec
