let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R11 — stage0-gcc-10.4.0  ★ THE PIVOT ★  — RETARGETED 2026-07-01 (was 10.5.0).  Closes B3's lower
# spine: a seed-rooted MODERN C/C++ compiler.  Edge: built BY R9 gcc-4.7.4's g++, using R8's
# gmp-6.2.1/mpfr-4.1.0/mpc-1.2.1 (/usr/lib/gcc-math), linked musl-1.2.5 (R7), assembled by
# binutils (R10=2.41 intended; R5=2.30 stand-in until R10 is drafted — see TODO below).
#
# ✅  RETARGET 10.5.0 -> 10.4.0 — WHY (was a SHOWSTOPPER; now resolved with ZERO new gcc rung):
#   gcc-10.5.0 REQUIRES an ISO **C++11** host compiler (that bootstrap requirement was back-ported
#   into the 10.5 POINT release: "versions prior to 10.5 bootstrap with C++98, 10.5+ require C++11").
#   R9 gcc-4.7.4's C++11 is EXPERIMENTAL/INCOMPLETE (no inheriting constructors, no full
#   thread_local) → it CANNOT compile gcc-10.5's C++ source, and NO CXX flag fixes a missing-feature
#   (capability) gap; --disable-bootstrap makes it WORSE (host g++ compiles every .cc directly, no
#   stage2 rescue).  gcc-10.4.0 is the LAST C++98-bootstrappable gcc → R9 gcc-4.7.4 builds it
#   DIRECTLY.  We take that path (vs. inserting an R9.5 = gcc-4.8.5 intermediate rung): no new rung,
#   the forward map's rung count is unchanged.  The CC import below stays the single swap-point in
#   case an intermediate builder is ever preferred.
# ============================================================================================
# Q1: R8's gmp/mpfr/mpc EXCEED gcc-10.4's minimums (GMP>=4.3.2, MPFR>=3.1.0, MPC>=1.0.1) — reused as-is.
# Q2: ISL is Graphite-only + orthogonal to LTO → --without-isl, and NEVER put ISL in the closure. No ISL rung.
# Q4: the siginfo/ucontext seds are NO-OPS on 10.4 (fixed upstream in gcc-8); kept only as harmless guards.
#     --disable-libsanitizer/libssp/libgomp/libquadmath amputates Alpine's musl patch surface. No new seds.
# ============================================================================================

# ── CC/CXX SWAP-POINT ────────────────────────────────────────────────────────────────────────
# Per forward map: R9 gcc-4.7.4, which builds 10.4.0 DIRECTLY (10.4 is C++98-bootstrappable — see
# banner).  If an intermediate builder is ever preferred, change THIS ONE import to
# `../stage0-gcc-4.8.5` (or 4.9.4/6.5.0/9.5.0).
let stage0-cc = import "../stage0-gcc-4.7.4/build.ncl" in             # R9: CC=gcc, CXX=g++ (+ its musl libstdc++)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # R8: /usr/lib/gcc-math (libgmp/mpfr/mpc.a) — cc1's middle-end
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in        # R7: /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
# R10 = binutils-2.41 (SEALED 2026-07-02) — the ladder's assembler for the pivot; glibc later needs binutils>=2.39.
let stage0-binutils = import "../stage0-binutils-2.41/build.ncl" in    # R10: as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in                     # configure's cmp/diff (R8 wall #4)
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in                                   # gcc-10.4 ships .tar.xz (NOT bz2 — R9 was bz2)
let findutils = import "../findutils/build.ncl" in                     # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in           # gcc build: options.c via awk, etc.
let version = "10.4.0" in
{
  name = "stage0-gcc-10.4.0",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,   # record-at-pin-time byte-identity seal (UNPINNED placeholder)
    {
      # upstream gcc-10.4.0 FULL tarball (.tar.xz — needs C++ → NOT gcc-core).  byte-identical mirror
      # (sha preserved → sha-pinned resolvedDeps).  extract=false (build.sh untars).
      # sha256 VERIFIED 2026-07-01: downloaded from ftp.gnu.org, sha512 matched GCC's authoritative
      #   gcc.gnu.org/pub/gcc/releases/gcc-10.4.0/sha512.sum EXACTLY (ftp.gnu.org has no per-dir
      #   sha512.sum for 10.4.0; no gpg in this env → sha512 cross-check was the trust anchor).
      # ✅ MIRRORED 2026-07-02: gs://minimal-staging-archives/gcc-10.4.0.tar.xz uploaded (operator write —
      #   the agent's shared-bucket write was classifier-gated), sha256 preserved == below.
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
      sha256 = "c9297d5bcd7cb43f3dfc2fed5389e948c9312fd962ef6a4ce455cff963ebe4f1",
      extract = false,
    } | Source,
    stage0-cc,            # R9 (intended): CC/CXX — see the swap-point above
    stage0-gmp-mpfr-mpc,  # R8: gmp/mpfr/mpc (--with-gmp/mpfr/mpc=/usr/lib/gcc-math)
    stage0-musl-r7,       # R7: musl-1.2.5 sysroot
    stage0-binutils,      # R10 (binutils-2.41): as/ld/ar/ranlib
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
    #   the <vector>/<memory>/… headers install to /usr/include/c++/10.4.0/:
    cxx_headers = { glob = "usr/include/c++/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gcc",
    } | Attrs,
} | BuildSpec
