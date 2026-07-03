let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B5 — gcc-15.2.0-glibc  ★ THE SELF-HOSTING FIXED POINT ★  (REVIEW-READY scaffold 2026-07-03)
# The from-source, GLIBC-LINKED twin of R12 (stage0-gcc-15.2.0).  Same PRODUCTION gcc-15.2.0 source +
# sha the ecosystem ships (packages/gcc), built BY R12 (the musl-linked gcc-15.2.0 driver) but now
# targeting the from-source glibc-2.42 (B4 = glibc-bedrock-2.42) and emitting the GLIBC-LINKED SHARED
# runtime libs the 368 downstream packages dynamically link: libstdc++.so.6, libgcc_s.so.1, libgomp.so,
# libatomic.so, libquadmath.so.  Assembled/linked by the NEW binutils-2.46-glibc (the matched set).
#
# "Self-hosting fixed point" (buildplan B5): the glibc-linked gcc this produces must be able to rebuild
# ITSELF.  Byte-identity to the debian prebuilt is EXPLICITLY NOT expected (a different compiler built
# it -> different bytes; readiness risk #3).  The determinism proof is B6 (differential-coreutils),
# NOT a byte-seal here.
#
# ── R12(musl) -> B5(glibc) DELTA (the exact flips; see build.sh for line-level detail) ─────────────
#   1. CC/CXX host compiler: stage0-gcc-10.4.0 (R11) -> stage0-gcc-15.2.0 (R12/self).  A musl-linked
#      driver retargets to glibc output fine via -B/-L/sysroot.
#   2. SR sysroot: /usr/lib/musl-bedrock-1.2.5 -> /usr/lib/glibc-bedrock-2.42 (B4's versioned sysroot,
#      UAPI co-located); host wrappers + target flags DROP `-static` (glibc is dynamic).
#   3. DELETE the load-bearing `sed os/gnu-linux -> os/generic` (that was a MUSL ctype workaround;
#      glibc WANTS os/gnu-linux — its _ISupper/_ISalpha ctype path is correct).  Single biggest libstdc++ flip.
#   4. DROP --with-native-system-header-dir=$SR/include (R12 set it to musl to hide glibc's
#      sys/single_threaded.h; B5 wants glibc headers at the default /usr/include — production posture).
#   5. --enable-shared (drop --disable-shared): produce libstdc++.so.6 + libgcc_s.so.1 + libgomp.so + ...
#   6. DROP --disable-lto and the --disable-libgomp/libatomic/libquadmath/libitm/libssp/libsanitizer set;
#      ADD --enable-default-pie --enable-default-ssp --disable-fixincludes (production ABI).
#   7. ADD the production x86_64 t-linux64 lib64->lib sed (glibc slibdir=/usr/lib parity).
#   8. gmp/mpfr/mpc: KEEP R8 stage0-gmp-mpfr-mpc (musl-static .a, gcc's bignum MIDDLE-END — statically
#      linked into cc1, libc-agnostic, does NOT affect the target ABI).  The production glibc-linked
#      gmp-6.3.0/mpfr-4.2.2/mpc-1.4.0 RUNTIME leaves are a SEPARATE B5 sub-rung (readiness follow-up).
#
# ⚠ DESIGN FORK (host libc) — reviewer decision, flagged in the readiness note.  This scaffold follows
#   the recon directive (host programs xgcc/cc1/cc1plus glibc-DYNAMIC, interp /lib64/ld-linux-x86-64.so.2).
#   HAZARD: R12's g++ links its OWN libstdc++.a (built against MUSL); compiling the C++ host programs
#   (cc1plus/f951) with R12 and linking them against glibc mixes a musl-built libstdc++.a into a glibc
#   binary (the "compiles != correct" / R4-silent-corruption zone).  Option A (safer, NOT taken here):
#   keep host programs MUSL-static (R12's proven wrappers verbatim) while building only the TARGET libs
#   glibc-shared — the host/target split standard cross-compilers use.  The gate below is the backstop
#   either way.  DECIDE before the first cloud build.
# ============================================================================================
# ── seed-rooted toolchain ──
let stage0-cc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC=gcc-15.2.0, CXX=g++ (+ its musl libstdc++) — the host compiler (was R11 gcc-10.4.0)
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # B5: the NEW glibc-linked as/ld/ar (built FIRST; the matched set)
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: /usr/lib/glibc-bedrock-2.42 versioned sysroot (the TARGET libc)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # R8: /usr/lib/gcc-math (libgmp/mpfr/mpc.a) — cc1's bignum middle-end
let stage0-linux-headers = import "../stage0-linux-headers-6.12.43/build.ncl" in # kernel UAPI at /usr/include (glibc headers #include <linux/...>)
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # gcc-15.2.0 ships .tar.xz
let findutils = import "../findutils/build.ncl" in # Model-B mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # gcc build: options.cc via awk, etc.
let version = "15.2.0" in
{
  name = "gcc-15.2.0-glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local, # NO byte-seal at B5 by design; functional-anchor placeholder + B6 note
    {
      # PRODUCTION gcc-15.2.0 FULL tarball (.tar.xz) — SAME source + sha as R12 / packages/gcc.  So the
      # glibc twin builds the EXACT ecosystem compiler, just seed-rooted + glibc-retargeted.  Already
      # mirrored + sha-verified.  extract=false (build.sh untars with --no-same-owner).
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e",
      extract = false,
    } | Source,
    stage0-cc, # R12 (gcc-15.2.0): CC/CXX host compiler
    binutils-glibc, # B5: glibc-linked as/ld/ar/ranlib (the matched-set assembler)
    glibc-bedrock, # B4: the TARGET glibc sysroot
    stage0-gmp-mpfr-mpc, # R8: gmp/mpfr/mpc middle-end (--with-gmp/mpfr/mpc=/usr/lib/gcc-math)
    stage0-linux-headers, # kernel UAPI at /usr/include (glibc headers need <linux/...>)
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
  # outputs — model on production packages/gcc/build.ncl so the glibc SHARED runtime libs are captured.
  outputs = {
    # the gcc/g++/gfortran/cpp drivers (+ the x86_64-linux-gnu- driver):
    bins = { glob = "usr/bin/*" } | OutputBin,

    # ★ the GLIBC-LINKED SHARED runtime libs the 368 pkgs dynamically link (NET-NEW vs R12 --disable-shared):
    libs = { glob = "usr/lib/**/*.{a,o,so*}", allow_data = true } | OutputLib, # allow_data: a few .so's are ld scripts/stubs
    libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,
    libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # libgcc_s.so is a stub that does not parse in the checker
    libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
    libstdcpp = { glob = "usr/lib/libstdc++*.so*", allow_data = true } | OutputLib,
    libquadmath = { glob = "usr/lib/libquadmath*.so*" } | OutputLib, # amd64 (fortran/quad); harmless-empty if c,c++ only

    # cc1 + cc1plus + collect2 + lto1 + lto-wrapper (+ f951 if fortran):
    libexec_bins = { glob = "usr/libexec/gcc/*/*/{cc1,cc1plus,f951,collect2,lto1,lto-wrapper}" } | OutputBin,
    liblto_plugin = { glob = "usr/libexec/gcc/*/*/liblto_plugin.so" } | OutputLib,
    # libgcc.a + crtbegin/crtend.o + specs + gcc's internal + libstdc++ target headers:
    internals = { glob = "usr/lib/gcc/**", allow_executable = true } | OutputData,
    libs_all = { glob = "usr/lib/**", allow_executable = true } | OutputData,
    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,

    # the C++ standard headers (<vector>/<memory>/…) install to /usr/include/c++/15.2.0/:
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
