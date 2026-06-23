let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
# R2 — stage0-tcc-0.9.26 (mes-tcc). The FIRST "real" C compiler in the bedrock climb:
# janneke's tcc-0.9.26 fork, compiled by MesCC (mes-m2 + mescc.scm, from R1) and linked
# against R1's mes-libc, then bootstrapped through tcc-mes -> tcc-boot0 -> boot1 -> boot2
# -> the final /usr/bin/tcc. R3 (tcc-0.9.27) builds ON this tcc.
#
# DRIVER = the ATTESTED full C kaem (/usr/bin/kaem, 6364de59…), supplied here by R0.5
# (stage0-mescc-full re-exports R0's kaem byte-identically), run --strict so it ABORTS HARD
# on any non-zero child. No bash: the B1.5 no-bash-driver property is preserved for the
# mes/tcc rungs. (bash re-enters only at R5/binutils where configure+make demand a shell —
# cf. the sibling stage0-binutils-2.30.) tcc.kaem is upstream steps/tcc-0.9.26/pass1.kaem
# with ONLY env/unpack/gate/staging scaffolding adapted; the if/match arch blocks + the
# ~200-file unified-libc.c catm + every -D list are byte-verbatim.
#
# ── CROSS-RUNG WIRING (CONTRACTS.md, ratified 2026-06-20) ─────────────────────────────────
# (A) SOLE TOOLCHAIN SUPPLIER = R0.5. R2 imports ONLY stage0-mescc-full (whole) + stage0-mes
# (whole, R1) for the toolchain — it does NOT import stage0-mescc (R0) directly. R0.5
# re-exports the four R0-owned tools R2 needs (kaem, catm, M1, hex2) ALONGSIDE its six
# final tools (M2-Mesoplanet, match, simple-patch, blood-elf, …), so the FINAL blood-elf /
# M2-Mesoplanet / match / simple-patch AND the kaem/catm/M1/hex2 backends all arrive at
# /usr/bin with no R0-vs-R0.5 path collision (a whole-Build dep maps the dep's ENTIRE
# output dir; build_deps are NOT transitively overlaid — only each dep's direct outputs
# land here, and R0/R0.5 have no runtime_deps, so R0's /usr/bin is NOT dragged in). No R0
# rebuild; R0 is a transitive predecessor via R0.5 (chain-enforce follows the build_dep DAG).
# NB: `subsetOf` in build_deps PANICS the deployed spec-hasher (CONTRACTS §0-ii), so the
# brief's "import only R0's M1/hex2/kaem" path is unavailable — whole-Build imports only.
# (C) R1 (stage0-mes) exports mes-m2 + mescc.scm + mes-libc (/usr/lib/x86_64-mes/**) + headers
# (/usr/include/**) + the THREE regenerated Scheme module trees at the §C-1 paths
# (/usr/share/mes/mes/module, /usr/share/mes/module, /usr/share/nyacc/module). R2 imports
# R1 whole and sets GUILE_LOAD_PATH to exactly those three roots (see tcc.kaem).
# (D) writable-/usr: minimal mounts the dep rootfs (incl. /usr) READ-ONLY; builds write to
# OUTPUT_DIR=/build/output (vendor CLAUDE.md "Output staging"). So R2 writes its tcc
# binaries + tcc-rebuilt mes-libc into /build/output/usr/** (BINDIR/LIBDIR redirected),
# reads R1's mes in place at the CONSUMER /usr/..., and bakes the consumer /usr path into
# the DELIVERABLE tcc. See tcc.kaem §LIBDIR + BUILD-RUNBOOK.md §D.
# (E) Triplet: x86_64-mes throughout (no i686 ref) — already correct, no change. This pkg dir
# is dotted (stage0-tcc-0.9.26) — fine as a STRING; any downstream rung importing R2 MUST
# bind it DOTLESS (e.g. `let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl"`).
#
# Trust spine: the predecessor edges are stage0-mes (R1) + stage0-mescc-full (R0.5). The
# recursive signer walk reaches the seed: R2 -> R1 -> R0.5 -> R0 -> stage0-kaem -> stage0-hex1
# -> stage0-hex0 -> the 229-byte hex0 seed. Source provenance = the sha-pinned janneke tcc
# fork + mes-0.27.1, mirrored byte-identically to our archives bucket (sha preserved ->
# recorded as sha-pinned resolvedDependencies).
let stage0-mes = import "../stage0-mes/build.ncl" in # R1 — mes-m2, mescc.scm, mes-libc, headers, module trees
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5 — kaem(driver)+catm+M1+hex2 + M2-Mesoplanet+match+simple-patch+blood-elf
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cp,chmod,mkdir,rm,sha256sum} — bare-name generic ops
{
  name = "stage0-tcc-0.9.26",
  build_deps = [
    { file = "tcc.kaem" } | Local, # the kaem driver (derived from pass1.kaem)
    { file = "stage0.answers" } | Local, # sha256sum -c byte-identity gate (RECORD-AT-PIN-TIME for amd64)
    { file = "remove-fileopen.before" } | Local, # verbatim live-bootstrap simple-patch pattern
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    # amd64 gfunc_call fix — cache `vtop - i` so mescc stops corrupting the 4th+ arg type (5 sites)
    { file = "gf-count.before" } | Local,
    { file = "gf-count.after" } | Local,
    { file = "gf-clf.before" } | Local,
    { file = "gf-clf.after" } | Local,
    { file = "gf-swapf.before" } | Local,
    { file = "gf-swapf.after" } | Local,
    { file = "gf-swapb.before" } | Local,
    { file = "gf-swapb.after" } | Local,
    { file = "gf-trail.before" } | Local,
    { file = "gf-trail.after" } | Local,
    # NOTE (§simple-patch): simple-patch.c is shipped too but is INERT by default — the PRIMARY
    # plan (CONTRACTS §B) consumes /usr/bin/simple-patch from R0.5. It is kept only for the
    # self-contained fallback (compile here via M2-Mesoplanet + the reused stage0-posix M2libc).
    { file = "simple-patch.c" } | Local,
    {
      # janneke's lilypond tcc-0.9.26 fork (the mes-tcc base). Upstream sha256 from
      # live-bootstrap steps/tcc-0.9.26/sources (lilypond.org/janneke/tcc/tcc-0.9.26-1147-gee75a10c.tar.gz);
      # PINNABLE NOW (byte-identical mirroring preserves the .tar.gz sha — memory
      # feedback_mirror_to_staging). Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= TCC_PKG).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — re-extracted so tcc rebuilds mes-libc (lib/*.c, lib/libtcc1.c,
      # lib/posix/getopt.c) from source with tcc-mes. SAME upstream sha as R1's mes Source
      # (live-bootstrap steps/mes-0.27.1/sources). Extracts to /build/mes-0.27.1/ (= MES_PKG).
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    # compiler-spine predecessor edges (chain-enforce) — toolchain taken WHOLE from R0.5+R1 only:
    stage0-mes, # R1: /usr/bin/{mes-m2,mescc.scm} + /usr/lib/x86_64-mes/** + /usr/include/** + /usr/share/{mes,nyacc}/**
    stage0-mescc-full, # R0.5: /usr/bin/{kaem(=driver),catm,M1,hex2,blood-elf,match,M2-Mesoplanet,simple-patch}
    coreutils, # /usr/bin/{cp,chmod,mkdir,rm,sha256sum} (no name collision with the R0.5 export set)
  ],
  # tcc-mes/tcc-boot*/tcc are STATIC ELF (CONFIG_TCC_STATIC=1, linked against mes-libc) — no
  # .interp / DT_NEEDED — so allow_missing_interpreter=true and there are no runtime_deps.
  cmds = [
    # Single handoff to R0.5's attested full C kaem. --file (NOT positional — the full kaem
    # rejects positional args; it routes the script ONLY via -f/--file); --strict + --verbose
    # for parity with R0.5/R1. tcc.kaem ALSO opens `set -ex` (belt-and-suspenders).
    ["/usr/bin/kaem", "--strict", "--verbose", "--file", "tcc.kaem"],
  ],
  outputs = {
    # the deliverable R3 (tcc-0.9.27) builds on (CONSUMER /usr path baked — see tcc.kaem §LIBDIR):
    tcc = { glob = "usr/bin/tcc", allow_missing_interpreter = true } | OutputBin,
    tcc_ver = { glob = "usr/bin/tcc-0.9.26", allow_missing_interpreter = true } | OutputBin,
    # RECORD-AT-PIN-TIME intermediate compilers (kept for audit / failure localization). NB:
    # these bake the STAGING libdir (/build/output/usr/lib/mes) — the deterministic OUTPUT_DIR —
    # so the self-referential boot loop resolves its freshly-built libc under read-only /usr
    # (CONTRACTS §D refinement; reproducible because OUTPUT_DIR is fixed). tcc-boot2 is NOT
    # exported (it is rm'd after it links the deliverable tcc).
    tcc_mes = { glob = "usr/bin/tcc-mes", allow_missing_interpreter = true } | OutputBin,
    tcc_boot0 = { glob = "usr/bin/tcc-boot0", allow_missing_interpreter = true } | OutputBin,
    tcc_boot1 = { glob = "usr/bin/tcc-boot1", allow_missing_interpreter = true } | OutputBin,
    # the tcc-rebuilt mes-libc that tcc-0.9.27 (R3) links against (crt1.o + libc.a + libgetopt.a;
    # crti.o/crtn.o are EMPTY on amd64 — the x86-only branch is skipped — but are captured if present):
    mes_libc = { glob = "usr/lib/mes/*.{a,o}" } | OutputLib,
    tcc_lib = { glob = "usr/lib/mes/tcc/libtcc1.a" } | OutputLib,
  },
  # attrs: upstream_version + repology_project (advisory String metadata). source_provenance is
  # DROPPED — its schema (attr_classes.ncl) admits only 'GnuProject/'GithubRepo/'Sourceforge/
  # 'Website; the draft's 'OtherSource is not a valid category, and the janneke/lilypond mes-tcc
  # fork (tarball at lilypond.org/janneke/tcc/) fits none cleanly. The AUTHORITATIVE provenance
  # is the sha-pinned tcc Source build_dep (recorded as a resolvedDependency), so the advisory
  # attr is unnecessary. (R0/R0.5/R1 likewise omit source_provenance.)
  attrs =
    {
      upstream_version = "0.9.26",
      repology_project = "tinycc",
    } | Attrs,
} | BuildSpec
