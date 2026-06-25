let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
# R3 — stage0-tcc-0.9.27.  The SECOND C compiler in the bedrock climb: mainline tinycc
# 0.9.27 (download.savannah.gnu.org/releases/tinycc), compiled by R2's WORKING tcc-0.9.26
# and linked against R2's tcc-rebuilt mes-libc, then used to re-build the mes-libc once more.
# R4 (musl-1.1.24) builds ON this tcc.
#
# This is a MAJOR simplification of R2: there is NO mescc and NO boot loop.  R2 cracked the
# upstream-unsolved mescc->tcc wall (live-bootstrap #470); from here the climb is a correct
# compiler building the next compiler.  ONE `tcc-0.9.26 -static -o tcc … tcc.c` compile, then
# a `-c`/`-ar`-only mes-libc rebuild (tcc-0.9.27 is never used to LINK an executable in R3, so
# its own linker — and any -static PLT defect — is not exercised here; that waits for R4).
#
# DRIVER = the same ATTESTED full C kaem (/usr/bin/kaem, 6364de59…, re-exported by R0.5), run
# --strict so any non-zero child ABORTS HARD.  No bash — the B1.5 no-bash-driver property holds
# for the whole mes/tcc spine (bash re-enters only at R5/binutils where configure+make need a
# shell).  tcc.kaem is upstream steps/tcc-0.9.27/pass1.kaem with env/unpack/gate/staging
# scaffolding adapted and the amd64 selections (TCC_TARGET_X86_64 / x86_64-mes-gcc) applied.
#
# ── WHY THE PATCH SET DIFFERS FROM R2 ───────────────────────────────────────────────────────
# DROPPED (all of R2's mescc-miscompile fixes): fix-shift / fix-swapf / fix-swapb / fix-mul /
#   fix-vararg fixed bugs in *mescc's* codegen.  R3 is compiled by tcc-0.9.26, a correct C
#   compiler, so none apply.  fix-plt (a genuine tcc -static linker defect) is also dropped:
#   R3 never links an executable with tcc-0.9.27, so its linker is inert here (R4 will need it).
# REUSED (verbatim, applied to the SAME freshly-extracted mes-0.27.1):
#   fix-stdarg — mes's include/stdarg.h is stack-based and SHADOWS tcc-0.9.27's own SysV-correct
#     include/stdarg.h (found first via `-I include`), so tcc-0.9.27-compiled vfprintf would read
#     phantom stack slots.  Patch makes mes's stdarg.h use __builtin_va_* under __TINYC__ (matches
#     tcc-0.9.27's ABI).  Same root cause as R2; tcc-0.9.27 is the same SysV tcc lineage.
#   fix-setjmp — basic-asm setjmp rewrite; a correct setjmp regardless of whether tcc-0.9.27
#     handles mes's extended-asm output operand, so safe to keep (functionally equivalent).
# R3-SPECIFIC (from upstream steps/tcc-0.9.27/simple-patches, on tcc-0.9.27's tcctools.c/tccelf.c):
#   {remove,addback}-fileopen — relocate the fopen() in tcc's -ar archiver (byte-identical to R2's
#     pair; tcc-0.9.27 ships the same tcctools.c).  fiwix-paddr + check-reloc-null — upstream's two
#     tccelf.c fixes (applied for fidelity to the upstream R3 step).
# va_list.o — tcc-0.9.27's lib/va_list.c (the __va_start/__va_arg runtime) goes into libtcc1.a on
#   amd64 (the Makefile's OBJ-x86_64 lists it; i386 does not need it — stack-based varargs).
#
# ── CROSS-RUNG WIRING (mirrors R2's CONTRACTS.md model) ─────────────────────────────────────
# R2 (stage0-tcc-0.9.26) supplies tcc-0.9.26 (the compiler) + its tcc-rebuilt mes-libc at the
#   CONSUMER /usr/lib/mes (crt1.o/libc.a/libgetopt.a + tcc/libtcc1.a) — tcc-0.9.26 bakes that
#   path, so it links tcc-0.9.27 by finding R2's libc there (read-only).
# R1 (stage0-mes) supplies the mes libc HEADERS at /usr/include (top-level) + /usr/include/mes,
#   which tcc-0.9.26 needs to compile tcc-0.9.27's tcc.c (#include <stdlib.h> …).  R3 does NOT run
#   mescc, so no GUILE_LOAD_PATH / mes-m2 / module trees are needed (env is simpler than R2's).
# R0.5 (stage0-mescc-full) supplies the kaem driver + catm + simple-patch.  coreutils supplies
#   cp/mkdir/chmod/sha256sum.  (build_deps are NOT transitively overlaid — each must be explicit.)
# §D writable-/usr: /usr is mounted READ-ONLY; R3 WRITES tcc-0.9.27 + the rebuilt mes-libc into
#   OUTPUT_DIR=/build/output (BINDIR/LIBDIR redirected there).  Because tcc-0.9.27 is used only for
#   -c/-ar in R3, the DELIVERABLE bakes the CONSUMER /usr/lib/mes directly (no staging-path dance
#   like R2's boot loop needed — there is no self-link to resolve).
#
# Trust spine: predecessor edges R2 -> R1 -> R0.5 -> R0 -> stage0-kaem -> … -> the 229-byte hex0
# seed.  Source provenance = the sha-pinned upstream tinycc 0.9.27 tarball + mes-0.27.1, mirrored
# byte-identically to our archives bucket (sha preserved -> sha-pinned resolvedDependencies).
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in # R2 — tcc-0.9.26 + tcc-rebuilt mes-libc at /usr/lib/mes
let stage0-mes = import "../stage0-mes/build.ncl" in # R1 — mes libc headers at /usr/include(+/mes)
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5 — kaem(driver) + catm + simple-patch
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cp,chmod,mkdir,sha256sum}
{
  name = "stage0-tcc-0.9.27",
  build_deps = [
    { file = "tcc.kaem" } | Local, # the kaem driver (derived from pass1.kaem)
    { file = "stage0.answers" } | Local, # sha256sum -c byte-identity gate (RECORD-AT-PIN-TIME for amd64)
    # tcctools.c -ar fopen relocation (byte-identical to R2's pair; tcc-0.9.27 ships same tcctools.c):
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    # upstream R3's two tccelf.c fixes (applied for fidelity to steps/tcc-0.9.27/pass1.kaem):
    { file = "fiwix-paddr.before" } | Local,
    { file = "fiwix-paddr.after" } | Local,
    { file = "check-reloc-null.before" } | Local,
    { file = "check-reloc-null.after" } | Local,
    # [R3 completeness 2026-06-25] THREE upstream tcc-0.9.27 patches from live-bootstrap's patches/ dir
    # (the unified-diff set, distinct from simple-patches/) that R3 originally MISSED — the first is the
    # R4 syscall.h wall (tcc-0.9.27 SIGSEGVs parsing `char buf[static N]` array params). See tcc.kaem.
    { file = "ignore-static-inside-array.before" } | Local,
    { file = "ignore-static-inside-array.after" } | Local,
    { file = "dont-skip-weak-symbols-ar.before" } | Local,
    { file = "dont-skip-weak-symbols-ar.after" } | Local,
    { file = "static-link.before" } | Local,
    { file = "static-link.after" } | Local,
    # REUSED from R2 (same fresh mes-0.27.1): mes stdarg.h -> SysV under __TINYC__ (shadows tcc's own),
    # and the basic-asm setjmp rewrite.  See the header note above for why these two survive but the
    # mescc-fix patches do not.
    { file = "fix-stdarg.before" } | Local,
    { file = "fix-stdarg.after" } | Local,
    { file = "fix-setjmp.before" } | Local,
    { file = "fix-setjmp.after" } | Local,
    {
      # mainline tinycc 0.9.27.  Upstream sha256 from live-bootstrap steps/tcc-0.9.27/sources
      # (download.savannah.gnu.org/releases/tinycc/tcc-0.9.27.tar.bz2); mirrored byte-identically
      # to our archives bucket (the .tar.bz2 sha is preserved).  Extracts to /build/tcc-0.9.27/.
      url = "gs://minimal-staging-archives/tcc-0.9.27.tar.bz2",
      sha256 = "de23af78fca90ce32dff2dd45b3432b2334740bb9bb7b05bf60fdbfc396ceb9c",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — re-extracted so tcc-0.9.27 re-builds mes-libc (lib/*.c, lib/posix/getopt.c)
      # from source.  SAME upstream sha as R1/R2's mes Source.  Extracts to /build/mes-0.27.1/.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    # compiler-spine predecessor edges (chain-enforce):
    stage0-tcc-r2, # R2: /usr/bin/{tcc-0.9.26,tcc,…} + /usr/lib/mes/** (the libc tcc-0.9.26 links against)
    stage0-mes, # R1: /usr/include/** (mes libc headers for the tcc.c self-compile)
    stage0-mescc-full, # R0.5: /usr/bin/{kaem(=driver),catm,simple-patch,…}
    coreutils, # /usr/bin/{cp,chmod,mkdir,sha256sum}
  ],
  # tcc-0.9.27 + the rebuilt mes-libc are STATIC ELF (CONFIG_TCC_STATIC=1) — no .interp / DT_NEEDED.
  cmds = [
    ["/usr/bin/kaem", "--strict", "--verbose", "--file", "tcc.kaem"],
  ],
  outputs = {
    # the deliverable R4 (musl-1.1.24) builds on (CONSUMER /usr/lib/mes baked — see tcc.kaem):
    tcc = { glob = "usr/bin/tcc", allow_missing_interpreter = true } | OutputBin,
    tcc_ver = { glob = "usr/bin/tcc-0.9.27", allow_missing_interpreter = true } | OutputBin,
    # the tcc-0.9.27-rebuilt mes-libc that musl's build links against (crt1.o + libc.a + libgetopt.a;
    # crtn.o/crti.o are EMPTY on amd64 — no x86_64 crtn.c/crti.c — so not enumerated):
    mes_libc = { glob = "usr/lib/mes/*.{a,o}" } | OutputLib,
    tcc_lib = { glob = "usr/lib/mes/tcc/libtcc1.a" } | OutputLib,
  },
  attrs =
    {
      upstream_version = "0.9.27",
      repology_project = "tinycc",
    } | Attrs,
} | BuildSpec
