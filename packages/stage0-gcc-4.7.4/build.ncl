let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let sealed-glibc = (import "../hex0/ladder-tools.ncl").glibc in # sealed ladder tools link libc
# stage0-gcc-4.7.4: gcc 4.7.4 with C and C++ (cc1, cc1plus, g++, static libstdc++), built by
# stage0-gcc-4.0.4 and linked statically against the musl-1.2.5 sysroot, using gmp/mpfr/mpc from
# stage0-gmp-mpfr-mpc (/usr/lib/gcc-math) and as/ld/ar/ranlib from stage0-binutils-2.30. See build.sh.
let stage0-gcc-4-0-4 = import "../stage0-gcc-4.0.4/build.ncl" in # CC (via the gcc-cc wrapper)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # /usr/lib/gcc-math: libgmp/libmpfr/libmpc.a + headers
let stage0-musl-1-2-5 = import "../stage0-musl-1.2.5/build.ncl" in # /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
let stage0-binutils-2-30 = import "../stage0-binutils-2.30/build.ncl" in # as/ld/ar/ranlib
let bash = (import "../hex0/ladder-tools.ncl").bash-bootstrap in
let make = (import "../hex0/ladder-tools.ncl").make in
let sed = (import "../hex0/ladder-tools.ncl").sed in
let grep = (import "../hex0/ladder-tools.ncl").grep in
let diffutils = (import "../hex0/ladder-tools.ncl").diffutils in # configure's cmp/diff
let coreutils = (import "../hex0/ladder-tools.ncl").coreutils in
let tar = (import "../hex0/ladder-tools.ncl").tar in
let bzip2 = (import "../hex0/ladder-tools.ncl").bzip2 in # .tar.bz2 source
let findutils = (import "../hex0/ladder-tools.ncl").findutils in # mtime guard: find . -exec touch
let gawk-bootstrap = (import "../hex0/ladder-tools.ncl").gawk-bootstrap in
# pkgmgr: bootstrap_rung = "hex0"
let version = "4.7.4" in
let amd64_spec =
  {
    name = "stage0-gcc-4.7.4",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # byte-identity pins (unpinned placeholder)
      {
        # full gcc-4.7.4 tarball (.tar.bz2; C++ needs the full tarball, not gcc-core). extract=false:
        # build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/gcc-%{version}.tar.bz2",
        sha256 = "92e61c6dc3a0a449e62d72a38185fda550168a86702dea07125ebd3ec3996282",
        extract = false,
      } | Source,
      stage0-gcc-4-0-4, # CC
      stage0-gmp-mpfr-mpc, # --with-gmp/mpfr/mpc=/usr/lib/gcc-math
      stage0-musl-1-2-5, # musl-1.2.5 sysroot
      stage0-binutils-2-30, # as/ld/ar/ranlib
      bash,
      make,
      sed,
      grep,
      diffutils,
      coreutils,
      sealed-glibc,
      tar,
      bzip2,
      findutils,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    cmd = "./build.sh",
    outputs = {
      # gcc/g++/cpp + the x86_64-linux-gnu-prefixed driver. allow_executable: ELF programs kept as
      # OutputData because they carry the stage0 musl interpreter, which OutputBin's checker rejects.
      bin = { glob = "usr/bin/*", allow_executable = true } | OutputData,
      # cc1 + cc1plus + collect2
      libexec = { glob = "usr/libexec/**", allow_executable = true } | OutputData,
      # libgcc.a + crtbegin/crtend.o + specs + gcc's internal headers (usr/lib/gcc/<tgt>/<ver>/)
      internals = { glob = "usr/lib/gcc/**", allow_executable = true } | OutputData,
      # libstdc++.a + libsupc++.a install to usr/lib (--disable-shared), not usr/lib/gcc; g++ is
      # unusable without them. The single-level glob is disjoint from usr/lib/gcc/** (literal_separator).
      cxx_libs = { glob = "usr/lib/*.a" } | OutputLib,
      # the C++ standard headers at usr/include/c++/<ver>/**
      cxx_includes = { glob = "usr/include/c++/**" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "gcc",
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-gcc-4.7.4",
      build_deps = [],
    } | BuildSpec,
} target
