let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
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
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let binutils-arm-none-eabi = import "../binutils-arm-none-eabi/build.ncl" in

let gcc_version = "14.2.0" in
let newlib_version = "4.4.0.20231231" in
{
  name = "gcc-arm-none-eabi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/gcc/gcc-%{gcc_version}/gcc-%{gcc_version}.tar.xz",
      sha256 = "a7b39bc69cbf9e25826c5a60ab26477001f7c08d85cec04bc0e29cabed6f3cc9"
    } | Source,
    {
      url = "https://sourceware.org/pub/newlib/newlib-%{newlib_version}.tar.gz",
      sha256 = "0c166a39e1bf0951dfafcd68949fe0e4b6d3658081d6282f39aeefc6310f2f13"
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
  # cc1/cc1plus/lto1 link libgmp, libmpfr, libmpc and libz/libzstd dynamically (build.sh passes
  # --with-gmp/--with-mpfr/--with-mpc=/usr --with-system-zlib; mpc ships only libmpc.so*). They
  # used to arrive undeclared through bash -> ncurses -> subsetOf gcc -> gcc's runtime_deps.
  runtime_deps = [
    bash,
    binutils-arm-none-eabi,
    gmp,
    mpc,
    mpfr,
    zlib,
    zstd,
  ],

  # A box with only this package (plus the shell and coreutils the commands need) must be able to
  # run cc1 and as: compile and assemble a trivial file for a Cortex-M target.
  tests = {
    compile_object =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "printf 'int add(int a, int b) { return a + b; }\\n' > t.c"],
          ["/bin/arm-none-eabi-gcc", "-mcpu=cortex-m4", "-mthumb", "-O2", "-c", "t.c", "-o", "t.o"],
          ["/bin/bash", "-c", "test -s t.o"],
        ],
      } | Test,
  },

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
} | BuildSpec
