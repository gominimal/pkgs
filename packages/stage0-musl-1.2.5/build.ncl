let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R7 — stage0-musl-1.2.5.  The MODERN libc, and the FIRST bedrock rung whose CC is a real gcc.
# ============================================================================================
# Built by the from-source gcc-4.0.4 (R6), assembled/linked by binutils-2.30 (R5).  Because the
# compiler is now a real gcc — not tcc-0.9.27 — NONE of R4's tcc-workaround patches apply
# (skip-pic-crt / drop-dynamic-crt / amd64-va-list / amd64-syscall-arch / the SSE asm-rm / @PLT
# strip / the tcc-ar empty-archive touch).  gcc handles PIC %rip crt, __builtin_va_list, the
# `register long r10 __asm__("r10")` syscall extension, SSE `.s`, @PLT relocs, and empty archives
# natively.  So this is (aspirationally) a STOCK musl build: configure -> make -> install, ZERO
# patches.  Any wall that appears is expected to be gcc-4.0.4-is-a-2005-compiler C-compat, not a
# codegen defect (the keystone risk died at R6).
#
# THE ONE BEDROCK NUANCE — the gcc-cc WRAPPER (build.sh §WRAPPER).  Our gcc-4.0.4's baked include/
# lib/crt search points at the coin-flip /usr (the glibc-linked shell tools' merged rootfs — see
# [[minimal_rootfs_nondeterministic_pollution]]).  The wrapper forces gcc onto R4b's CLEAN
# /usr/lib/musl-bedrock sysroot: `-nostdinc -isystem <gcc-freestanding>` on COMPILE (musl ships its
# OWN 1.2.5 headers via -nostdinc -Iinclude, so we add ONLY gcc's stddef.h/stdarg.h, never R4b's
# 1.1.24 libc headers); `-B/-L musl-bedrock` on LINK so configure-probe links resolve musl crt+libc,
# not glibc.  Same anti-pollution posture as R5/R6, ported from tcc's musl-cc to gcc.
#
# WHY R4b (1.1.24) IS STILL A DEP: it is the BOOTSTRAP link libc for gcc's configure probes (musl's
# configure compiles+links a few tiny probes).  musl-1.2.5's own libc.a is built from its OWN .o
# (compiled -c, ar'd) and NEVER links against R4b — so 1.1.24 is inert for the produced libc bytes.
#
# CLEAN SINGLE-WRITER SYSROOT: published at /usr/lib/musl-bedrock-1.2.5 (VERSIONED — distinct from
# R4b's /usr/lib/musl-bedrock so the two musls never collide in a downstream sandbox's unordered
# /usr merge).  R8+ (gmp/mpfr/mpc, gcc-4.7.4) point the gcc-cc wrapper at THIS 1.2.5 sysroot.
#
# TODO (deferred, not needed to BUILD musl): the ladder pairs R7 with linux-4.14.336 kernel headers
# (`make headers_install ARCH=x86`).  musl builds standalone without them; downstream rungs that
# #include <linux/*.h> (likely R9 gcc-4.7.4) will need them — add as a second Source + install step then.
# ============================================================================================
let stage0-gcc = import "../stage0-gcc-4.0.4/build.ncl" in            # R6: CC (gcc/cc1/cpp + libgcc.a) driven via the gcc-cc wrapper
let stage0-musl-r4b = import "../stage0-musl-1.1.24-cc2/build.ncl" in # R4b: /usr/lib/musl-bedrock clean sysroot (bootstrap link libc for configure probes)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # R5: as/ld/ar/ranlib on PATH (gcc's driver assembles+links; archive index)
let bash = import "../bash/build.ncl" in                             # ./build.sh driver + configure shell
let make = import "../make/build.ncl" in                             # build engine
let sed = import "../sed/build.ncl" in                               # configure: config.mak generation
let grep = import "../grep/build.ncl" in                             # configure probes
let coreutils = import "../coreutils/build.ncl" in                   # rm/mkdir/cp/ln/install/sha256sum
let tar = import "../tar/build.ncl" in                               # build.sh `tar -xf`
let gzip = import "../gzip/build.ncl" in                             # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in         # musl configure's awk
let version = "1.2.5" in
{
  name = "stage0-musl-1.2.5",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,  # sha256sum -c byte-identity seal — record-at-pin-time (UNPINNED placeholder; gcc IS deterministic so promotable to fatal once pinned)
    {
      # upstream musl 1.2.5 (byte-identical mirror; sha preserved -> sha-pinned resolvedDeps).
      # extract=false — build.sh runs `tar -xf` itself (bash-build convention).
      url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
      sha256 = "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4",
      extract = false,
    } | Source,
    stage0-gcc,          # R6: the CC (via gcc-cc wrapper) — brings R4b musl + binutils in its closure too
    stage0-musl-r4b,     # R4b: explicit — the /usr/lib/musl-bedrock sysroot the wrapper links against
    stage0-binutils-r5,  # R5: explicit — as/ld/ar/ranlib on PATH
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    gzip,
    gawk-bootstrap,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # SAME shape as R4b — the static libc + crt + stub archives + headers downstream rungs consume:
    libc = { glob = "usr/lib/libc.a" } | OutputLib,
    crt = { glob = "usr/lib/*.o" } | OutputLib,
    libs = { glob = "usr/lib/*.a" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    # VERSIONED clean single-writer sysroot (see header §SYSROOT).  Single-level usr/lib/*.{a,o} globs
    # above do NOT match this nested path (literal_separator), so it is not double-captured.
    sysroot_inc = { glob = "usr/lib/musl-bedrock-1.2.5/include/**" } | OutputData,
    sysroot_lib = { glob = "usr/lib/musl-bedrock-1.2.5/lib/**" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "musl",
    } | Attrs,
} | BuildSpec
