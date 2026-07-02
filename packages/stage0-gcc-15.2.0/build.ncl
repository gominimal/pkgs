let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R12 — stage0-gcc-15.2.0  — the FIRST from-source MODERN PRODUCTION compiler.  Built BY the R11 pivot
# (gcc-10.4.0), using R8's gmp-6.2.1/mpfr-4.1.0/mpc-1.2.1 (/usr/lib/gcc-math), linked musl-1.2.5 (R7),
# assembled by binutils-2.41 (R10).  This is the EXACT version minimal's production stdenv ships
# (packages/gcc = 15.2.0) — so B4/B5 can re-root the toolchain onto it with the 368 pkg recipes UNCHANGED.
# glibc-2.42 hard-requires gcc>=12.1, so R12 is the modern-gcc gate before the B4 glibc hop.
#
# ✅  HOST-LANGUAGE GATE CLEARED (probe-confirmed 2026-07-02, gcc-15.2.0/gcc/doc/install.texi:225):
#   gcc-15 requires an ISO **C++14** host compiler ("versions prior to 15 allow C++11; prior to 10.5
#   allow C++98").  The R11 pivot gcc-10.4.0 has COMPLETE C++14 + C++17 → it clears the bar with margin.
#   This is the INVERSE of the fatal 10.5 case (host gcc-4.7.4 had only experimental C++11): here the host
#   is a modern gcc, so a single 10.4->15.2 hop is valid with NO stepping stone.  (gcc-14.3.0 is mirrored
#   as the ICE fallback if the 5-major jump miscompiles under --disable-bootstrap.)
# ============================================================================================
# Q1: R8's gmp/mpfr/mpc EXCEED gcc-15's minimums (GMP>=4.3.2, MPFR>=3.1.0, MPC>=0.8.1 — probe-confirmed) — reused as-is.
# Q2: ISL is Graphite-only + orthogonal to LTO → --without-isl, and NEVER put ISL in the closure. No ISL rung.
# Q3: os/gnu-linux->os/generic libstdc++ ctype sed STILL fires (probe: token present at configure.host:277).
# Q4: the siginfo/ucontext seds are NO-OPS on 15 (fixed upstream in gcc-8); kept only as harmless guards.
#     flex/bison needed ONLY for the cobol parser (not built) → shipped-generated + Model-B holds.
# ============================================================================================

# ── CC/CXX SWAP-POINT ────────────────────────────────────────────────────────────────────────
# The R11 pivot gcc-10.4.0 builds 15.2.0 DIRECTLY (host C++14 gate cleared — see banner).  If the 5-major
# jump ever ICEs, change THIS ONE import to `../stage0-gcc-14.3.0` (mirrored) as a stepping stone.
let stage0-cc = import "../stage0-gcc-10.4.0/build.ncl" in # R11 pivot: CC=gcc-10.4.0, CXX=g++ (+ its musl libstdc++)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # R8: /usr/lib/gcc-math (libgmp/mpfr/mpc.a) — cc1's middle-end
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in # R7: /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
# R10 = binutils-2.41 (SEALED 2026-07-02) — the ladder's assembler for the pivot; glibc later needs binutils>=2.39.
let stage0-binutils = import "../stage0-binutils-2.41/build.ncl" in # R10: as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff (R8 wall #4)
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # gcc-10.4 ships .tar.xz (NOT bz2 — R9 was bz2)
let findutils = import "../findutils/build.ncl" in # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # gcc build: options.c via awk, etc.
let version = "15.2.0" in
{
  name = "stage0-gcc-15.2.0",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local, # record-at-pin-time byte-identity seal (UNPINNED placeholder)
    {
      # PRODUCTION gcc-15.2.0 FULL tarball (.tar.xz — needs C++).  SAME source + sha as minimal's
      # production packages/gcc (version 15.2.0) → R12 builds the EXACT ecosystem compiler, just
      # seed-rooted (musl-linked, built by the R11 pivot) instead of debian-prebuilt-seeded.  So B4/B5
      # re-root the stdenv onto R12 with the 368 pkg recipes UNCHANGED.  Already mirrored + sha-verified.
      # extract=false (build.sh untars with --no-same-owner).
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e",
      extract = false,
    } | Source,
    stage0-cc, # R11 pivot (gcc-10.4.0): CC/CXX — see the swap-point above
    stage0-gmp-mpfr-mpc, # R8: gmp/mpfr/mpc (--with-gmp/mpfr/mpc=/usr/lib/gcc-math)
    stage0-musl-r7, # R7: musl-1.2.5 sysroot
    stage0-binutils, # R10 (binutils-2.41): as/ld/ar/ranlib
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
  cmd = "./build.sh",
  outputs = {
    # the gcc-10.4 drivers the ecosystem uses as CC/CXX (gcc/g++/cpp + the x86_64-linux-gnu- driver):
    bin = { glob = "usr/bin/*" } | OutputData,
    # cc1 + cc1plus + collect2 (the C and C++ compilers + link wrapper):
    libexec = { glob = "usr/libexec/**" } | OutputData,
    # libgcc.a + crtbegin/crtend.o + specs + gcc's internal + libstdc++ target headers:
    internals = { glob = "usr/lib/gcc/**" } | OutputData,
    # ★ NET-NEW vs R9: capture the C++ standard library + its headers (g++ is useless without them).
    #   libstdc++.a / libsupc++.a install to $(libdir)=/usr/lib under --disable-shared:
    cxx_libs = { glob = "usr/lib/*.a" } | OutputLib,
    #   the <vector>/<memory>/… headers install to /usr/include/c++/15.2.0/:
    cxx_headers = { glob = "usr/include/c++/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gcc",
    } | Attrs,
} | BuildSpec
