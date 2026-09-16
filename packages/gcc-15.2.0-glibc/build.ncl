let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# gcc-15.2.0-glibc: the production gcc-15.2.0 source (same sha as packages/gcc) built by
# stage0-gcc-15.2.0 and targeting glibc-bedrock-2.42, producing the glibc-linked shared runtime
# libraries downstream packages link (libstdc++.so.6, libgcc_s.so.1, libgomp, libatomic,
# libquadmath), assembled by binutils-2.46-glibc. gmp/mpfr/mpc come from stage0-gmp-mpfr-mpc: they
# are linked statically into cc1 and do not affect the target ABI. Byte parity with the prebuilt gcc
# is not expected (a different compiler built it). See build.sh for the configure flags and gates.
let stage0-cc = import "../stage0-gcc-15.2.0/build.ncl" in # CC=gcc-15.2.0, CXX=g++ (with its musl libstdc++): the host compiler
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # glibc-linked as/ld/ar/ranlib
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # target glibc sysroot at /usr/lib/glibc-bedrock-2.42
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # /usr/lib/gcc-math: libgmp/libmpfr/libmpc.a for cc1
let stage0-linux-headers = import "../stage0-linux-headers-6.12.43/build.ncl" in # kernel UAPI at /usr/include (glibc headers include <linux/...>)
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # .tar.xz source
let findutils = import "../findutils/build.ncl" in # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # gcc's build regenerates options.cc via awk
let version = "15.2.0" in
let amd64_spec =
  {
    name = "gcc-15.2.0-glibc",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # no byte-identity pins for this package; see the file
      match {
        { arch = 'Amd64, .. } =>
          {
            # full gcc-15.2.0 tarball (.tar.xz), same source and sha as stage0-gcc-15.2.0 and the
            # production gcc package. extract=false: build.sh untars with --no-same-owner.
            url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
            sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e",
            extract = false,
          } | Source,
        { arch = 'Arm64, .. } =>
          {
            # aarch64 prebuilt from the arm64 bootstrap chain: gcc-15.2.0 with glibc and g++. Root-shaped
            # usr/ tree with bin/{gcc,g++}, lib/gcc/aarch64-linux-gnu/15.2.0, include/c++/15.2.0;
            # build.sh extracts it verbatim.
            url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/6715136640b3e12d04231c34d4b17f0f39e7e034b94450a27769ca49e91ce5ad/stage0-gcc-15.2.0-glibc-aarch64.tar.zst",
            sha256 = "6715136640b3e12d04231c34d4b17f0f39e7e034b94450a27769ca49e91ce5ad",
            extract = false,
          } | Source,
      } target,
      stage0-cc, # CC/CXX host compiler
      binutils-glibc, # glibc-linked as/ld/ar/ranlib
      glibc-bedrock, # target glibc sysroot
      stage0-gmp-mpfr-mpc, # --with-gmp/mpfr/mpc=/usr/lib/gcc-math
      stage0-linux-headers, # kernel UAPI at /usr/include
      bash,
      make,
      sed,
      grep,
      diffutils,
      coreutils,
      tar,
      xz,
      findutils,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    # The binaries are glibc-dynamic against the sysroot (interp + rpath under
    # /usr/lib/glibc-bedrock-2.42/lib), so its libc.so.6/libm.so.6/loader must be declared or the
    # missing-runtime_deps check fails. Only sysroot_lib: the full glibc-bedrock would put a second
    # usr/include and usr/bin next to the toolchain glibc in every consumer sandbox.
    # find_lib_in_deps globs `**/<soname>`, so the versioned sysroot path matches.
    runtime_deps = [
      subsetOf glibc-bedrock ["sysroot_lib"],
    ],

    cmd = "./build.sh",
    # outputs follow the production gcc package so the shared runtime libs are captured.
    outputs = {
      # gcc/g++/gfortran/cpp drivers (+ the x86_64-linux-gnu- driver)
      bins = { glob = "usr/bin/*" } | OutputBin,

      # the glibc-linked shared runtime libs downstream packages link
      libs = { glob = "usr/lib/**/*.{a,o,so*}", allow_data = true } | OutputLib, # allow_data: a few .so files are linker scripts/stubs
      libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,
      libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # libgcc_s.so is a linker script the checker cannot parse
      libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
      libstdcpp = { glob = "usr/lib/libstdc++*.so*", allow_data = true } | OutputLib,
      libquadmath = { glob = "usr/lib/libquadmath*.so*" } | OutputLib, # fortran/quad; empty if only c,c++ are built

      # cc1 + cc1plus + collect2 + lto1 + lto-wrapper (+ f951 with fortran)
      libexec_bins = { glob = "usr/libexec/gcc/*/*/{cc1,cc1plus,f951,collect2,lto1,lto-wrapper}" } | OutputBin,
      liblto_plugin = { glob = "usr/libexec/gcc/*/*/liblto_plugin.so" } | OutputLib,
      # libgcc.a + crtbegin/crtend.o + specs + gcc's internal and libstdc++ target headers
      internals = { glob = "usr/lib/gcc/**", allow_executable = true } | OutputData,
      libs_all = { glob = "usr/lib/**", allow_executable = true } | OutputData,
      ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,

      # the C++ standard headers at /usr/include/c++/15.2.0/
      cxx_headers = { glob = "usr/include/c++/**" } | OutputData,
      includes = { glob = "usr/include/**" } | OutputData,
      share_data = { glob = "usr/share/gcc-*/**" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "gcc",
        source_provenance = {
          category = 'GnuProject,
          name = "gcc",
        },
        build_cost_multiple = 2,
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "gcc-15.2.0-glibc",
      build_deps = [],
    } | BuildSpec,
} target
