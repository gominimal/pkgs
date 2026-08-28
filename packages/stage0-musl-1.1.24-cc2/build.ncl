let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# R4b — stage0-musl-1.1.24-cc2.  The DETERMINISTIC SECOND-PASS musl: byte-identical source + patches to
# R4a (stage0-musl-1.1.24), but compiled by the CACHED, LOTTERY-FREE tcc-musl2 (from s3) instead of the
# R3 mes-linked tcc-0.9.27.  This is the musl the downstream rungs (s4 correctness gate, R5 binutils) link
# against — it escapes R4a's ~5% mes-libc arena lottery AND fixes the silent fmt_fp long-double `.data`
# zeroing BY CONSTRUCTION, because tcc-musl2 is a musl-linked (no mes-libc) compiler with no allocator
# lottery: its codegen is deterministic, so a musl built by it is correct + reproducible.
#
# ── WHY R4b IS SOUND / NO CYCLE ─────────────────────────────────────────────────────────────
# Bootstrap order:  R4a (lottery, transient)  →  s1/s3 (tcc-musl2, cached, codegen-validated by s4)
#                →  R4b (this rung: deterministic correct musl, SEALED)  →  s4 / binutils.
# R4b depends on s3 (tcc-musl2); s3 depends (transitively, via s1) on R4a; R4b is a SEPARATE rung from
# R4a, so there is no cycle.  R4a STAYS AS-IS — it is the transient that already birthed tcc-musl2; R4b
# does NOT replace it in the s1→s3 birth chain, it only supersedes R4a as the libc DOWNSTREAM rungs link.
#
# ── WHAT COMPILES MUSL / HEADER RESOLUTION (the crux of the R4a→R4b swap) ────────────────────
# CC = tcc-musl2 (/usr/bin/tcc-musl2, from s3): a MUSL-linked tcc-0.9.27 — NO mes-libc, NO arena lottery,
#   fully DETERMINISTIC.  Its integrated assembler + linker are the SAME tcc-0.9.27 codegen as R3's tcc
#   (s3's tccsrc = R3-patched tcc-0.9.27 + GOT fixes A/B/C in the LINKER; the preprocessor/include-search
#   code is byte-identical), so the amd64 codegen LIMITS are identical → the SAME amd64 patches + SSE/asm
#   `rm`s + syscall patch that R4a carries are carried here verbatim.
# HEADERS: musl compiles `-nostdinc -Iinclude` and SHIPS ITS OWN include/stddef.h + include/stdarg.h
#   (verified in the sha-pinned musl 1.1.24 source).  So stddef.h/stdarg.h resolve from musl's OWN tree,
#   NOT from any compiler builtin-header dir.  tcc-0.9.27 only adds CONFIG_TCC_SYSINCLUDEPATHS when NOT
#   -nostdinc (libtcc.c:946 `if (!s->nostdinc)`), and tcc-musl2 baked that to a bare "/usr/include" (no
#   {B}/include) — so tcc-musl2 needs NO builtin-header dir installed for the musl compile.  This is the
#   SAME mechanism R4a's R3-tcc uses; the compiler swap does NOT change header resolution for the
#   -nostdinc build.  What tcc-musl2 DOES need in the env is only: itself (/usr/bin/tcc-musl2) + its
#   libtcc1.a (/usr/lib/tcc/libtcc1.a, s3's baked TCC_LIBGCC path — the FLOAT gate links against it).
# The bootstrap musl at /usr/include (from R4a, dep below) exists ONLY to satisfy tcc-musl2's baked
#   sysinclude for musl's trivial configure probes (`#include <stdlib.h>` — no __GLIBC__ ⇒ wrapper=none,
#   identical outcome to R4a's mes headers).  The REAL libc bytes come from R4b's OWN build → $OUTPUT_DIR;
#   the compile is -c/-ar only (never links against /usr/lib), so R4a's libc at /usr/lib is inert here.
#   This dep pattern is copied from s4 (stage0-tcc-0.9.27-musl-s4): tcc-musl2 (s3) + musl (R4a), NO R1/mes.
#
# ── amd64 ADAPTATION (identical to R4a — see stage0-musl-1.1.24/build.ncl for the full analysis) ──
# --host=x86_64; only the four arch-neutral live-bootstrap patches + the five amd64-net-new patches
# (skip-pic-crt / drop-dynamic-crt / amd64-va-list / amd64-syscall-arch, plus the SSE/asm `rm`s in
# build.sh) apply — the i386-only upstream patches are intentionally NOT carried.  tcc-musl2's codegen
# limits == R3-tcc's, so this patch set is unchanged from R4a.
#
# Trust spine: compiler edge R4b → s3 → s1 → R2 → R1 → R0.5 → kaem → hex1 → the 229-byte hex0 seed
# (tcc-musl2 is seed-rooted through s1's tcc-0.9.26 birth).  Source provenance = the SAME sha-pinned
# upstream musl 1.1.24 tarball as R4a (byte-identical mirror; sha preserved → sha-pinned resolvedDeps).
let stage0-tcc-musl-s3 = import "../stage0-tcc-0.9.27-musl-s3/build.ncl" in # tcc-musl2 (deterministic, musl-linked) + libtcc1.a
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in # R4a — bootstrap musl headers at /usr/include for configure probes (inert for the compile)
let bash = import "../bash/build.ncl" in # ./build.sh driver (shell re-entry)
let make = import "../make/build.ncl" in # the build engine
let sed = import "../sed/build.ncl" in # configure: config.mak + wrapper generation
let grep = import "../grep/build.ncl" in # configure probes
let patch = import "../patch/build.ncl" in # apply the arch-neutral + amd64 patches
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{rm,mkdir,cp,chmod,install,cat,sort,tr,sha256sum,…} (NB: NOT tar)
let tar = import "../tar/build.ncl" in # build.sh `tar -xf` — a SEPARATE pkg, NOT part of coreutils
let gzip = import "../gzip/build.ncl" in # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # musl's configure uses awk once (bootstrap variant = light closure)
let version = "1.1.24" in # SOURCE tarball version (the musl-%{version}.tar.gz URL/sha); the -cc2 rung suffix lives in `name`
{
  name = "stage0-musl-1.1.24-cc2",
  build_deps = [
    { file = "build.sh" } | Local, # the bash driver (R4a's, with the lottery retry REMOVED + gate fail-shut)
    { file = "stage0.answers" } | Local, # sha256sum -c byte-identity seal — RECORD-AT-PIN-TIME; for R4b a REAL reproducibility invariant (deterministic build), promotable to fatal once pinned. Ships an UNPINNED placeholder.
    # ARCH-NEUTRAL + amd64 patches — BYTE-IDENTICAL to R4a (same musl source, same tcc-0.9.27 codegen
    # limits for tcc-musl2).  See stage0-musl-1.1.24/build.ncl for the per-patch rationale.
    { file = "makefile.patch" } | Local, # tcc -ar can't make empty archives -> `touch` the empty libs
    { file = "madvise_preserve_errno.patch" } | Local, # preserve errno across __madvise in malloc
    { file = "avoid_sys_clone.patch" } | Local, # posix_spawn: fork() instead of __clone (tcc/early-env safe)
    { file = "disable_ctype_headers.patch" } | Local, # drop iswalpha/… decls (no table regen)
    { file = "skip-pic-crt.patch" } | Local, # amd64: skip Scrt1.o/rcrt1.o (tcc segfaults on -fPIC %rip crt)
    { file = "drop-dynamic-crt.patch" } | Local, # amd64: drop _DYNAMIC lea from crt_arch.h (tcc asm segfault)
    { file = "amd64-va-list.patch" } | Local, # amd64: define __builtin_va_list via tcc's SysV __va_list_struct
    { file = "amd64-syscall-arch.patch" } | Local, # amd64: rewrite __syscall4/5/6 (tcc can't do GCC register-asm arg-pinning)
    {
      # SAME upstream musl 1.1.24 tarball + sha as R4a (byte-identical mirror; sha preserved).
      # extract=false — build.sh runs `tar -xf` itself (bash-build convention).
      url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
      sha256 = "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3",
      extract = false,
    } | Source,
    # compiler edge (this rung's DETERMINISTIC compiler) + environment (dep pattern mirrors s4):
    stage0-tcc-musl-s3, # tcc-musl2 (CC + `tcc-musl2 -ar`) at /usr/bin + libtcc1.a at /usr/lib/tcc/libtcc1.a
    stage0-musl-r4, # R4a: bootstrap musl headers at /usr/include (configure probes only) — NO R1/mes
    bash, # ./build.sh driver
    make, # build engine
    sed, # configure wrapper/config.mak
    grep, # configure probes
    patch, # apply the patches
    coreutils, # rm/mkdir/cp/chmod/install/cat/sort/tr/sha256sum
    tar, # build.sh `tar -xf musl-1.1.24.tar.gz`
    gzip, # tar's .gz decompression
    gawk-bootstrap, # musl configure's awk
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # SAME outputs as R4a — the static libc + crt + stub archives + headers the downstream rungs consume:
    libc = { glob = "usr/lib/libc.a" } | OutputLib,
    crt = { glob = "usr/lib/*.o" } | OutputLib,
    libs = { glob = "usr/lib/*.a" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    # CLEAN SINGLE-WRITER MUSL SYSROOT (bedrock anti-pollution — see build.sh §SYSROOT).  A byte-identical
    # COPY of the musl headers + static libc/crt above, published at a path NO OTHER package writes.  The
    # /usr copies above collide, in the merged sandbox rootfs, with the glibc-linked shell tools' `glibc`
    # runtime_dep (which ships the same usr/include/** + usr/lib/libc.a); minimal's rootfs overlay is an
    # UNORDERED hash-set with FIRST-writer-wins collision handling, so which of {musl,glibc} owns
    # /usr/include/stdio.h + /usr/lib/libc.a is a nondeterministic per-build coin-flip.  Downstream rungs
    # (s4 fixed-point gate, R5 binutils) point their compiler at THIS clean tree with -nostdinc + explicit
    # crt/libc, so the coin-flip can never feed them glibc.  Single-level `usr/lib/*.{a,o}` globs above do
    # NOT match this nested path (literal_separator), so it is not double-captured.
    sysroot_inc = { glob = "usr/lib/musl-bedrock/include/**" } | OutputData,
    sysroot_lib = { glob = "usr/lib/musl-bedrock/lib/**" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "musl",
    } | Attrs,
} | BuildSpec
