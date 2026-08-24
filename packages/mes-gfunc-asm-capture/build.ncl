let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# mes-gfunc-asm-capture — a SINGLE-BUILD GROUND-TRUTH forensics probe for the amd64 mes-tcc
# >=4-arg-call SIGSEGV. Instead of hypothesizing about HOW mescc miscompiles tcc-mes's gfunc_call,
# it CAPTURES the evidence: the mescc-EMITTED assembly (tcc.s, M1/stage0 syntax) for gfunc_call
# (the assert@1318 site + the SValue struct-copy swap) and the classify_x86_64_* trio, PLUS the
# linked tcc-mes binary for local `objdump -d`. All as retrievable OutputData — they ride out in
# the signed artifact and land in gs://minimalmertic-sign-staging/mes-gfunc-asm-capture-a/.
#
# It runs the ~250s mescc tcc.c->tcc.s long pole TWICE:
#   PHASE canonical : gf-UNpatched gfunc_call  -> tcc.s + slices + tcc-mes.canonical
#   PHASE patched   : the committed 5-site gf-* addressing fix applied -> tcc.s + slices + binary
# and DIFFS the two gfunc_call slices. That diff is the headline artifact: it shows EXACTLY which
# instructions the addressing fix changed and — critically — whether the suspect SValue struct-copy
# mov chains are byte-IDENTICAL between them. R2 still SIGSEGVs WITH the gf fix applied (commit
# 09a5824), so if the struct-copy asm is unchanged across the diff, that is direct proof the bug is
# the struct-copy, not the vtop[-i] addressing the fix rewrote — telling the next fix to be a
# field-by-field SValue swap, not another addressing tweak.
#
# HOW gfunc_call IS LOCATED IN tcc.s: mescc/M1 emits each C function as a COLUMN-0 label line
# `:<name>` (module/mescc/M1.scm:278) and every in-function local label as `:_<name>_<n>_...`
# (module/mescc/compile.scm:1110). So `:gfunc_call` is unambiguous (the PE def at source:784 is
# #ifdef'd out — only the SysV #else def at ~1195 reaches mescc), and the slice = from `:gfunc_call`
# through all `:_gfunc_call_*` locals, stopping at the next other column-0 `:identifier`. build.sh's
# slice_fn() is that awk, run per function.
#
# WHY NOT A KAEM RUNG: a diagnostic probe is not a trust rung, so it MAY use bash (build.sh,
# `set +e`) to tolerate sub-step failure and ALWAYS exit 0 with OutputData + greppable rows.
# Mirrors mes-tcc-libc-bisect / tcc-mes-4arg-probe / mes-stability-sweep.
#
# PINNING: stage0-mes (R1) + stage0-mescc-full (R0.5) are imported WHOLE so mes-m2 / mescc.scm /
# the regenerated nyacc tables / mes-libc (libc+tcc.a) / headers / simple-patch are the EXACT
# binaries the failing R2 build uses, read in place at /usr. The tcc + mes Sources are the SAME
# sha-pinned tarballs R2 compiles. The two tcctools.c fopen patches AND the 5 gf-* patches are the
# verbatim files committed in stage0-tcc-0.9.26, so the captured asm/binary are byte-faithful.
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: mes-m2 + mescc.scm + mes-libc (libc+tcc.a) + headers + module trees
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/simple-patch
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, arrays, the two-phase loop
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cp,chmod,mkdir,rm,wc,cat,head,tail,uname,timeout}
let grep = import "../grep/build.ncl" in # /usr/bin/grep — labels-and-moves convenience extract
let gawk = import "../gawk/build.ncl" in # /usr/bin/awk — slice_fn() (column-0 label walk)
let gzip = import "../gzip/build.ncl" in # /usr/bin/gzip — compress the ~123k-line full tcc.s
let diffutils = import "../diffutils/build.ncl" in # /usr/bin/diff — canonical-vs-patched gfunc_call diff
{
  name = "mes-gfunc-asm-capture",
  build_deps = [
    { file = "build.sh" } | Local, # the bash capture harness (PHASE canonical + PHASE patched + diff)
    # tcctools.c fopen relocation — applied in BOTH phases so the linked binary == the R2 binary
    # (tcctools.c is compiled in via ONE_SOURCE=1; gfunc_call asm is independent of it).
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    # the committed 5-site gfunc_call addressing fix (cache `vtop - i` into a local SValue*) —
    # applied ONLY in PHASE patched. VERBATIM copies of stage0-tcc-0.9.26/gf-*.{before,after}.
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
    {
      # janneke's lilypond tcc-0.9.26 fork — the SAME Source R2 compiles (byte-identical mirror,
      # sha preserved). Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= the mescc compile CWD).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — supplies mes-libc lib/** that tcc.c references via -l c+tcc at link,
      # plus the include/ tree. SAME upstream sha as R1/R2's mes Source. Extracts to /build/mes-0.27.1/.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    stage0-mes,
    stage0-mescc-full,
    bash-bootstrap,
    coreutils,
    grep,
    gawk,
    gzip,
    diffutils,
  ],
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    # MANIFEST (also tee'd to stdout -> debug-log bucket, retrievable even if capture is skipped).
    manifest = { glob = "usr/share/mes-gfunc-asm-capture/MANIFEST.txt" } | OutputData,
    # the per-function emitted-asm slices (both phases): gfunc_call*.s, classify_x86_64_*.s, gfunc_prolog*.s
    slices = { glob = "usr/share/mes-gfunc-asm-capture/*.s" } | OutputData,
    # the canonical-vs-patched diffs (gfunc_call + classify_x86_64_arg/inner)
    diffs = { glob = "usr/share/mes-gfunc-asm-capture/*.diff" } | OutputData,
    # the labels+moves convenience extracts
    moves = { glob = "usr/share/mes-gfunc-asm-capture/*.labels-and-moves.txt" } | OutputData,
    # the full emitted asm, gzipped (~123k lines raw): tcc.s.canonical.gz + tcc.s.patched.gz
    full_asm = { glob = "usr/share/mes-gfunc-asm-capture/tcc.s.*.gz" } | OutputData,
    # the linked tcc-mes binaries for local `objdump -d` (static ELF): tcc-mes.canonical + tcc-mes.patched
    binaries = { glob = "usr/share/mes-gfunc-asm-capture/tcc-mes.*" } | OutputData,
  },
} | BuildSpec
