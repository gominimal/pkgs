let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# mes-tcc-libc-bisect — a SINGLE-BUILD diagnostic that BUILDS the freshly-bootstrapped amd64
# tcc-mes (R2's now-reliable no-growth-arena path) and then BISECTS the `tcc-mes -c
# unified-libc.c` SIGSEGV — the NEW R2 wall (deterministic 2/2). One ~250s+ rebuild yields a
# localized verdict (size threshold? a specific .c file/construct? a cumulative-heap effect?)
# AND proves-or-refutes the per-file split-TU candidate fix, instead of the ONE data point a
# kaem rung gives (kaem --strict aborts on the first crash).
#
# THE BUG (distinct binary + class from the now-solved mes-m2 instability): the freshly mescc-
# built x86_64 tcc-mes runs `-version` fine and compiles crt1.o fine, then SIGSEGVs (bare
# `tcc-mes ... abnormal termination, signal number = 11`, NO tcc diagnostic) on exactly:
#     tcc-mes -c -D HAVE_CONFIG_H=1 -I include -I include/linux/x86_64 -o unified-libc.o unified-libc.c
# unified-libc.c = a `catm` of 258 mes-libc .c files into ONE giant TU. amd64 mes-tcc is
# GENUINELY UNVALIDATED upstream (live-bootstrap ships only x86/riscv64 tcc-0.9.26 checksums).
#
# LEADING HYPOTHESES THIS PROBE DISCRIMINATES:
#   H1 fixed-size tcc buffer/table overflow on the wide TU  -> per-file-OK + sharp size threshold.
#   H2 mescc-x86_64 MIScompiled tcc-mes; a code path latent on small inputs (PRIME named suspect:
#      x86_64-gen.c's long-double/x87 assert(0) stubs at :1092/:1313/:2256, reachable ONLY via
#      the SOLE long-double user in the TU, lib/stdlib/strtold.c) -> a SINGLE file crashes ALONE,
#      and removing strtold.c makes the full TU PASS.
#   H3 mes-libc bump-allocator heap exhaustion accumulated within one TU (free()=no-op, realloc
#      orphans) -> ALL files compile alone but the concatenation crashes; volume/order-driven.
#
# WHY NOT A KAEM RUNG: a diagnostic probe is NOT a trust rung, so it MAY use bash (build.sh,
# `set +e`) to tolerate per-subset crashes and loop. Mirrors mes-stability-sweep / ia32-probe:
# a non-trust probe that emits an OutputData artifact + greppable rows and ALWAYS exits 0.
#
# PINNING: stage0-mes (R1) + stage0-mescc-full (R0.5) are imported WHOLE so mes-m2 / mescc.scm /
# the regenerated nyacc tables / mes-libc (incl. libc+tcc.a) / headers / simple-patch are the
# EXACT binaries the failing R2 build uses, read in place at /usr. The tcc + mes Sources are the
# SAME sha-pinned tarballs R2 compiles. The probe applies BOTH tcctools.c simple-patches so the
# bisected tcc-mes is byte-identical to the production R2 binary that crashes (tcctools.c is
# compiled in via ONE_SOURCE=1) — closing the "you bisected a different binary" objection.
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: /usr/bin/{mes-m2,mescc.scm} + /usr/lib/x86_64-mes/** (incl libc+tcc.a) + /usr/include/** + /usr/share/{mes,nyacc}/module
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/{simple-patch,catm,...} — STAGE-A faithfulness (tcctools.c patch)
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, arrays, the per-subset loop
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cat,cp,chmod,mkdir,rm,wc,date,timeout,head,tail,seq}
let grep = import "../grep/build.ncl" in # /usr/bin/grep — classify() buckets a subset by rc + stderr signature
{
  name = "mes-tcc-libc-bisect",
  build_deps = [
    { file = "build.sh" } | Local, # the bash bisect harness (STAGE-A build tcc-mes; STAGE-B bisect)
    # the two tcctools.c simple-patches (verbatim live-bootstrap pattern files, copied from R2)
    # — applied in STAGE-A via /usr/bin/simple-patch so tcc-mes == the production R2 binary.
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    {
      # janneke's lilypond tcc-0.9.26 fork — the SAME Source R2 compiles (byte-identical mirror,
      # sha preserved). Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= STAGE-A compile CWD).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — supplies the 258 libc .c files (lib/**) that make up unified-libc.c
      # and the include/ tree. SAME upstream sha as R1/R2's mes Source. Extracts to /build/mes-0.27.1/.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    stage0-mes, # R1 — mes-m2 + mescc.scm + mes-libc (libc+tcc.a) + headers + module trees (read in place at /usr)
    stage0-mescc-full, # R0.5 — /usr/bin/simple-patch (+ catm); STAGE-A applies the tcctools.c patch
    bash-bootstrap,
    coreutils,
    grep,
  ],
  # Explicit bash (do NOT rely on a shebang/interp). build.sh is a Local file placed at /build.
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    # The RESULT TABLE. Also tee'd to stdout (lands in the debug-log bucket) so it is retrievable
    # even if the artifact capture is skipped. Harness ALWAYS exits 0 after emitting.
    matrix = { glob = "usr/share/mes-tcc-libc-bisect/matrix.txt" } | OutputData,
  },
} | BuildSpec
