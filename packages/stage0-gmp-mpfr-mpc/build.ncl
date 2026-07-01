let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R8 — stage0-gmp-mpfr-mpc.  gcc's exact-arithmetic trio (cc1's middle-end links libgmp/libmpfr/
# libmpc for constant folding).  Built by the from-source gcc-4.0.4 (R6), linked against musl-1.2.5
# (R7), assembled/archived by binutils-2.30 (R5).  The ladder's "most de-risked rung": three pure-C
# static libraries, no codegen exotica.  A COMBINED rung (one recipe, one seal, one vendor) because the
# three are always consumed together by R9 (gcc-4.7.4) and have a strict build order:
#     gmp  ->  mpfr (needs gmp)  ->  mpc (needs gmp + mpfr).
#
# CC = the gcc-cc WRAPPER, **libc-using variant** (build.sh §WRAPPER): gmp/mpfr/mpc are normal
# libc-using C programs (`#include <stdio.h>` …), so the wrapper adds musl-1.2.5's libc headers
# (`-isystem $SR/include`) on the COMPILE path — UNLIKE R7's freestanding musl build.  SR = R7's
# versioned sysroot /usr/lib/musl-bedrock-1.2.5.  gmp builds `--disable-assembly` (generic C mpn — no
# hand-written x86_64 .asm to hand gcc-4.0.4/binutils-2.30).
#
# OUTPUT: a clean single-writer tree at /usr/lib/gcc-math/{lib,include} (libgmp.a/libmpfr.a/libmpc.a +
# gmp.h/mpfr.h/mpc.h) — R9 points `--with-gmp=/usr/lib/gcc-math` (etc.) at it, avoiding the coin-flip /usr.
# ============================================================================================
let stage0-gcc = import "../stage0-gcc-4.0.4/build.ncl" in            # R6: CC (gcc/cc1/cpp + libgcc.a)
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in       # R7: /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # R5: as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in                                  # gmp + mpfr are .tar.xz
let gzip = import "../gzip/build.ncl" in                              # mpc is .tar.gz
let m4 = import "../m4/build.ncl" in                                  # gmp's configure/build may want m4 (present even w/ --disable-assembly)
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-gmp-mpfr-mpc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gmp-6.2.1.tar.xz",
      sha256 = "fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2",
      extract = false,
    } | Source,
    {
      url = "gs://minimal-staging-archives/mpfr-4.1.0.tar.xz",
      sha256 = "0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f",
      extract = false,
    } | Source,
    {
      url = "gs://minimal-staging-archives/mpc-1.2.1.tar.gz",
      sha256 = "17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459",
      extract = false,
    } | Source,
    stage0-gcc,          # R6: CC (via gcc-cc libc-using wrapper) — brings R7 musl + binutils in closure
    stage0-musl-r7,      # R7: explicit — the /usr/lib/musl-bedrock-1.2.5 sysroot the wrapper links
    stage0-binutils-r5,  # R5: explicit — as/ld/ar/ranlib on PATH
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    xz,
    gzip,
    m4,
    gawk-bootstrap,
  ],
  cmd = "./build.sh",
  outputs = {
    # clean single-writer math tree (R9 --with-gmp/mpfr/mpc points here):
    libs = { glob = "usr/lib/gcc-math/lib/*.a" } | OutputLib,
    includes = { glob = "usr/lib/gcc-math/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = "6.2.1",  # gmp-anchored; mpfr-4.1.0 + mpc-1.2.1 pinned in Sources above. NB: sign-staging forbids '+' in versions.
      repology_project = "gmp",
    } | Attrs,
} | BuildSpec
