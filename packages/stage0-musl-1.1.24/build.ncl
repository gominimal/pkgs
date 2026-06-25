let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# R4 — stage0-musl-1.1.24.  The FIRST real C library in the bedrock climb: musl 1.1.24
# (musl.libc.org/releases), compiled by R3's tcc-0.9.27 and INSTALLED as a static libc.a +
# crt*.o + headers.  R5 (the gcc-mesboot / binutils rungs) builds ON this musl instead of the
# mes-libc — musl is the libc the early GCCs link against.
#
# ── DRIVER = BASH RE-ENTRY (the first non-kaem rung) ────────────────────────────────────────
# Unlike R0-R3 (driven by the attested full C kaem), musl-1.1.24 builds with a hand-written
# `./configure` SHELL SCRIPT + `make` (live-bootstrap steps/musl-1.1.24/pass1.sh: `CC=tcc
# ./configure …` then `make … AR="tcc -ar"`).  Neither configure nor make runs under kaem, so
# R4 RE-ENTERS THE SHELL: the recipe is build.sh, run via `cmd = "./build.sh"`.  This is the
# rung where the B1.5 no-bash-driver property ends (R3's header said "bash re-enters at
# R5/binutils" — but musl is the real boundary because musl itself is configure+make).
# >> See OPEN QUESTIONS in build.sh: this pulls bash/make/sed/patch into R4's trust surface.
#
# ── WHAT COMPILES MUSL / WHAT IT LINKS AGAINST ──────────────────────────────────────────────
# CC=tcc  →  R3's tcc-0.9.27 compiles every musl .c AND assembles every musl .s via tcc's
# INTEGRATED assembler (no binutils `as` exists yet — that arrives at R5).  AR="tcc -ar" builds
# the archives (no binutils `ar` yet); RANLIB=true is a no-op.  musl is freestanding (-nostdinc,
# its OWN headers), so the build only does -c / -ar — it never LINKS an executable, hence
# tcc-0.9.27's -static linker (and R2's fix-plt PLT defect) is NOT exercised, and the R3
# mes-libc at /usr/lib/mes is effectively unused by the compile.  Output = a self-contained
# x86_64 static libc.a + crt*.o + headers (musl provides its own libc — it does not link mes-libc).
#
# ── amd64 ADAPTATION (this is the crux — live-bootstrap's musl path is 32-bit i386) ─────────
# live-bootstrap builds musl with `--host=i386`; we build `--host=x86_64` (configure.sh maps
# `x86_64*` -> ARCH=x86_64), selecting arch/x86_64 + src/*/x86_64.  CONSEQUENCE: almost ALL of
# upstream's musl patches are i386-ONLY and DO NOT APPLY to the x86_64 build:
#   set_thread_area / sigsetjmp / fenv / va_list  → patch files in arch/i386 or src/*/i386 that
#     are NEVER COMPILED when ARCH=x86_64 (they `patch` cleanly but are dead code) → DROPPED.
#   va_list (arch/i386/bits/alltypes.h.in)        → x86_64's alltypes.h.in ALREADY uses
#     `__builtin_va_list` unconditionally (tcc-0.9.27 supports it via lib/va_list.c in libtcc1.a),
#     so the tcc shim is unnecessary on amd64 → DROPPED.
#   avoid_set_thread_area                          → its arch-neutral src/env/__init_tls.c hunk
#     WOULD apply, but it pairs with an i386-only arch/i386/pthread_arch.h hunk; applying only
#     the neutral half would leave x86_64's `%fs:0` __pthread_self reading uninitialised TLS →
#     DROPPED (amd64 on the real CS kernel can do arch_prctl/ARCH_SET_FS natively).
# Only the four ARCH-NEUTRAL patches below are carried (verified to apply to the extracted
# x86_64 tree).  An amd64 fenv fix (src/fenv/x86_64/fenv.s uses stmxcsr/ldmxcsr — the very
# instrs upstream's i386 fenv.patch removes "because tcc does not support" them) is a LIKELY
# follow-up — see OPEN QUESTIONS in build.sh; it can only be settled by the first capture build.
#
# ── CROSS-RUNG WIRING (mirrors R3's CONTRACTS model) ────────────────────────────────────────
# R3 (stage0-tcc-0.9.27) supplies /usr/bin/tcc (CC=tcc + `tcc -ar`) + libtcc1.a + the /usr/lib/mes
#   libc (the latter unused by the -c/-ar-only musl build, kept for environment fidelity).
# R1 (stage0-mes) supplies the mes libc HEADERS at /usr/include(/mes) — tcc-0.9.27 bakes
#   CONFIG_TCC_SYSINCLUDEPATHS=/usr/include/mes, so configure's tiny probe compiles resolve their
#   stray #includes there (musl's real build is -nostdinc).  Defensive; see OPEN QUESTIONS.
# SHELL ENVIRONMENT — DECISION 2026-06-25 (RATIFIED: Option B). R4 BRIDGES on our EXISTING ATTESTED
#   shell tools rather than seed-rooting them first. Rationale: these DRIVE the build (configure +
#   make) but never enter the compiled artifact's lineage — musl's bytes derive ONLY from tcc-0.9.27
#   (seed-rooted) + the musl source, so the shell tools relocate trust to the attested builder image,
#   not reduce it to the seed. An acceptable bridge for the spine. Seed-rooting them (live-bootstrap's
#   make-3.82 / bash-2.05b / patch-2.5.9, tcc-built) is DEFERRED to B7/cutover — tracked in
#   .staging-ctx/bedrock-rollout-premortem (cross-cutting risk #3).
#   bash (./build.sh driver) · make (engine) · sed (config.mak) · grep (probes) · patch (4 patches) ·
#   coreutils (rm/mkdir/cp/sha256sum).
# §D writable-/usr: /usr is READ-ONLY; `make … DESTDIR=$OUTPUT_DIR install` redirects all writes
#   to /build/output (libc.a + crt*.o -> /usr/lib, headers -> /usr/include under DESTDIR).
#
# Trust spine: compiler-spine predecessor edge R3 -> R2 -> R1 -> R0.5 -> kaem -> hex1 -> the
# 229-byte hex0 seed.  Source provenance = the sha-pinned upstream musl 1.1.24 tarball, mirrored
# byte-identically to our archives bucket (sha preserved -> sha-pinned resolvedDependencies).
let stage0-tcc-r3 = import "../stage0-tcc-0.9.27/build.ncl" in # R3 — tcc-0.9.27 (CC + `tcc -ar`) + libtcc1.a + /usr/lib/mes
let stage0-mes = import "../stage0-mes/build.ncl" in # R1 — mes libc headers at /usr/include(+/mes) for configure probes
let bash = import "../bash/build.ncl" in # ./build.sh driver (shell re-entry)
let make = import "../make/build.ncl" in # the build engine
let sed = import "../sed/build.ncl" in # configure: config.mak + musl-gcc wrapper generation
let grep = import "../grep/build.ncl" in # configure probes
let patch = import "../patch/build.ncl" in # apply the 4 arch-neutral patches
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{rm,mkdir,cp,chmod,install,cat,sort,tr,sha256sum,…} (NB: NOT tar)
let tar = import "../tar/build.ncl" in # build.sh `tar -xf` — a SEPARATE pkg, NOT part of coreutils
let gzip = import "../gzip/build.ncl" in # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # musl's configure uses awk once (bootstrap variant = light closure, matches packages/make)
let version = "1.1.24" in
{
  name = "stage0-musl-1.1.24",
  build_deps = [
    { file = "build.sh" } | Local, # the bash driver (derived from live-bootstrap pass1.sh, amd64-adapted)
    { file = "stage0.answers" } | Local, # sha256sum -c byte-identity gate (RECORD-AT-PIN-TIME for amd64)
    # ARCH-NEUTRAL patches, copied byte-identically from live-bootstrap steps/musl-1.1.24
    # (verified to apply to the extracted x86_64 tree; the i386-only patches are intentionally
    # NOT carried — see the build.ncl header):
    { file = "makefile.patch" } | Local, # tcc -ar can't make empty archives -> `touch` the empty libs
    { file = "madvise_preserve_errno.patch" } | Local, # preserve errno across __madvise in malloc
    { file = "avoid_sys_clone.patch" } | Local, # posix_spawn: fork() instead of __clone (tcc/early-env safe)
    { file = "disable_ctype_headers.patch" } | Local, # drop iswalpha/… decls meslibc can't regenerate tables for
    # amd64-ONLY (net-new vs live-bootstrap's i386 path): skip the PIC crts (Scrt1.o/rcrt1.o) — tcc-0.9.27
    # segfaults on arch/x86_64/crt_arch.h's `lea _DYNAMIC(%rip),%rsi` under -fPIC. Static bootstrap uses crt1.o only.
    { file = "skip-pic-crt.patch" } | Local,
    # amd64-ONLY (net-new): tcc-0.9.27 segfaults ASSEMBLING crt_arch.h's `lea _DYNAMIC(%rip),%rsi`
    # (weak+hidden sym, RIP-rel reloc). Static crt1.c's _start_c uses only rdi, so rsi/_DYNAMIC is
    # vestigial -> replace with `xor %esi,%esi`. (Every -f/-W flag probe passed; only this asm crashes.)
    { file = "drop-dynamic-crt.patch" } | Local,
    {
      # upstream musl 1.1.24.  sha256 from live-bootstrap steps/musl-1.1.24/sources
      # (https://musl.libc.org/releases/musl-1.1.24.tar.gz); mirrored byte-identically to our
      # archives bucket (the .tar.gz sha is preserved).  extract=false — build.sh runs `tar -xf`
      # itself (the bash-build convention; matches packages/make, packages/coreutils).
      url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
      sha256 = "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3",
      extract = false,
    } | Source,
    # compiler-spine predecessor edge (chain-enforce) + environment:
    stage0-tcc-r3, # R3: /usr/bin/tcc (CC + `tcc -ar`) + libtcc1.a + /usr/lib/mes
    stage0-mes, # R1: /usr/include/** (mes headers for configure probes)
    bash, # ./build.sh driver
    make, # build engine
    sed, # configure wrapper/config.mak
    grep, # configure probes
    patch, # apply the 4 patches
    coreutils, # rm/mkdir/cp/chmod/install/cat/sort/tr/sha256sum
    tar, # build.sh `tar -xf musl-1.1.24.tar.gz`
    gzip, # tar's .gz decompression
    gawk-bootstrap, # musl configure's awk
  ],
  build_args = {
    include version,
  },
  # build.sh re-enters the shell (vs R0-R3's kaem); minimal runs it via the project bash-build path.
  cmd = "./build.sh",
  outputs = {
    # the static libc R5 links against:
    libc = { glob = "usr/lib/libc.a" } | OutputLib,
    # crt startup objects (crt1.o/crti.o/crtn.o/Scrt1.o/rcrt1.o — assembled by tcc from x86_64 crt*.s/.c):
    crt = { glob = "usr/lib/*.o" } | OutputLib,
    # the empty stub archives (libm/libpthread/librt/… are EMPTY on musl — `touch`ed via makefile.patch):
    libs = { glob = "usr/lib/*.a" } | OutputLib,
    # musl headers (the libc interface R5's compilers compile against):
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "musl",
    } | Attrs,
} | BuildSpec
