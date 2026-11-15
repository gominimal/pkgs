let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let mpc = import "../mpc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let bash = import "../bash/build.ncl" in
let binutils-arm-none-eabi = import "../binutils-arm-none-eabi/build.ncl" in

let gcc_version = "16.2.0" in
let newlib_version = "4.6.0.20260123" in
{
  name = "gcc-arm-none-eabi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/gcc/gcc-%{gcc_version}/gcc-%{gcc_version}.tar.xz",
      sha256 = "e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e"
    } | Source,
    {
      url = "https://sourceware.org/pub/newlib/newlib-%{newlib_version}.tar.gz",
      sha256 = "6ff27e3bf022666f43f7802255be680eeff722ac181b1725d21e2e8318604ee3"
    } | Source,
    base,
    make,
    toolchain,
    gmp,
    mpfr,
    mpc,
    zlib,
    zstd,
  ],
  runtime_deps = [
    bash,
    binutils-arm-none-eabi,
  ],

  cmd = "./build.sh",
  build_args = {
    include gcc_version,
    include newlib_version,
  },

  outputs = {
    bins = { glob = "usr/bin/arm-none-eabi-*" } | OutputBin,
    libexec_bins = { glob = "usr/libexec/gcc/arm-none-eabi/*/{cc1,cc1plus,collect2,lto1,lto-wrapper}" } | OutputBin,
    libexec_plugin = { glob = "usr/libexec/gcc/arm-none-eabi/*/plugin/**" } | OutputBin,
    liblto_plugin = { glob = "usr/libexec/gcc/arm-none-eabi/*/liblto_plugin.so*" } | OutputLib,
    libexec_data = { glob = "usr/libexec/gcc/arm-none-eabi/*/install-tools/**" } | OutputBin,
    target_libs = { glob = "usr/lib/gcc/arm-none-eabi/**", allow_executable = true } | OutputData,
    target_includes = { glob = "usr/arm-none-eabi/include/**" } | OutputData,
    target_newlib_libs = { glob = "usr/arm-none-eabi/lib/**", allow_executable = true } | OutputData,
    share = { glob = "usr/share/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = gcc_version,
      license_spdx = "(GPL-2.0-only AND GPL-3.0-only AND LGPL-2.1-only)",
      source_provenance = {
        category = 'GnuProject,
        name = "gcc",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/arm-none-eabi-gcc --version",
  },
} | BuildSpec
