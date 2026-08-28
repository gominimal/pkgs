let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R9 — stage0-gcc-4.7.4.  The FIRST C++ compiler in the bedrock climb (cc1plus / g++), and the
# highest-risk upper-spine rung.  Built by the from-source gcc-4.0.4 (R6), linked musl-1.2.5 (R7),
# using the gmp/mpfr/mpc trio (R8) for its middle-end, assembled/archived by binutils-2.30 (R5).
# It in turn builds R11 (gcc-10.5.0, the pivot).  DRAFT — build.ncl (dep graph) locked; build.sh is
# the next focused write (plan below), to iterate the moment R8 seals + vendors.
#
# CC = the gcc-cc WRAPPER, **libc-using variant** (as R8): gcc-4.0.4 forced onto R7's clean sysroot
#   /usr/lib/musl-bedrock-1.2.5 (`-nostdinc -isystem <gcc-freestanding> -isystem $SR/include` on compile;
#   `-B/-L $SR/lib -static` on link).  as/ld/ar/ranlib = binutils-2.30 (R5).
# MATH = R8's /usr/lib/gcc-math -> `--with-gmp=/usr/lib/gcc-math --with-mpfr=… --with-mpc=…` (cc1 links
#   libgmp/libmpfr/libmpc; that's the whole reason R8 exists).  R8 dropped its .la files, so gcc links the
#   static .a directly (no libtool-archive path games — see the R8 .la/DESTDIR lesson in the forward map).
#
# ── build.sh PLAN (adapt R6 stage0-gcc-4.0.4/build.sh; the gcc pattern is proven) ────────────────
#   * tar --no-same-owner -xf gcc-4.7.4.tar.bz2   (chown-hostile; the R8 wall)
#   * gcc-cc libc-using wrapper (copy R8's verbatim)
#   * Model-B: mtime-guard the shipped generated files newest + regen-tool stubs that fail LOUD
#       (⚠ UNVERIFIED for 4.7.4 — pass1.sh upstream invokes autoreconf/bison/flex; a local configure-probe
#        SHOULD run first to confirm the shipped tree is complete.  If a stub fires, that file needs adding
#        to the mtime list, or Model-A regen is required.)
#   * configure --prefix=/usr --disable-shared --disable-multilib --disable-nls --enable-languages=c,c++
#       --with-gmp=/usr/lib/gcc-math --with-mpfr=/usr/lib/gcc-math --with-mpc=/usr/lib/gcc-math
#       (+ per ladder: config.sub swap + cache-var env may be needed — confirm at first cloud build)
#   * no-op fixincludes/fixinc.sh stub (the PERMANENT gcc-rung pattern — R6 wall #6; check 4.7.4 for
#       --disable-fixincludes which would be cleaner)
#   * CPATH/LIBRARY_PATH -> the musl-bedrock-1.2.5 sysroot so the built xgcc's crtstuff/libgcc use musl
#       (R6 wall #5), -L $SR/lib for -lm (R6 wall #4)
#   * -j1 (OOM pole, esp. cc1plus); diffutils on PATH for configure's cmp/diff (R8 saw them missing)
# ============================================================================================
let stage0-gcc-405 = import "../stage0-gcc-4.0.4/build.ncl" in         # R6: CC (gcc-4.0.4 via gcc-cc wrapper)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # R8: /usr/lib/gcc-math (libgmp/libmpfr/libmpc.a + headers) — cc1's middle-end
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in        # R7: /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # R5: as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in                     # configure's cmp/diff (R8 showed them missing)
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in                             # gcc-4.7.4 ships .tar.bz2
let findutils = import "../findutils/build.ncl" in                    # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let version = "4.7.4" in
{
  name = "stage0-gcc-4.7.4",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,   # record-at-pin-time byte-identity seal (UNPINNED placeholder)
    {
      # upstream gcc-4.7.4 FULL tarball (.tar.bz2 — needs C++, so NOT gcc-core).  sha == ladder pin;
      # byte-identical mirror (sha preserved -> sha-pinned resolvedDeps).  extract=false (build.sh untars).
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.bz2",
      sha256 = "92e61c6dc3a0a449e62d72a38185fda550168a86702dea07125ebd3ec3996282",
      extract = false,
    } | Source,
    stage0-gcc-405,       # R6: CC
    stage0-gmp-mpfr-mpc,  # R8: gmp/mpfr/mpc (--with-gmp/mpfr/mpc=/usr/lib/gcc-math)
    stage0-musl-r7,       # R7: musl-1.2.5 sysroot
    stage0-binutils-r5,   # R5: as/ld/ar/ranlib
    bash,
    make,
    sed,
    grep,
    diffutils,
    coreutils,
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
    # the gcc-4.7.4 drivers R10/R11 use as CC (gcc/g++/cpp + the x86_64-linux-gnu-prefixed driver):
    bin = { glob = "usr/bin/*" } | OutputData,
    # cc1 + cc1plus + collect2 (the C and C++ compilers + link wrapper):
    libexec = { glob = "usr/libexec/**" } | OutputData,
    # libgcc.a + crtbegin/crtend.o + specs + gcc's internal headers (under usr/lib/gcc/<tgt>/<ver>/):
    internals = { glob = "usr/lib/gcc/**" } | OutputData,
    # CRITICAL: the C++ standard library (static, --disable-shared) installs to usr/lib/, NOT
    # usr/lib/gcc/ — libstdc++.a + libsupc++.a. WITHOUT these R9's g++ links nothing and is unusable
    # as R11's builder (workflow-caught 2026-07-01). Single-level usr/lib/*.a is disjoint from
    # usr/lib/gcc/** (literal_separator), so no double-capture with `internals`.
    cxx_libs = { glob = "usr/lib/*.a" } | OutputLib,
    # the C++ standard headers (<vector>, bits/, the target subdir) at usr/include/c++/<ver>/**:
    cxx_includes = { glob = "usr/include/c++/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gcc",
    } | Attrs,
} | BuildSpec
