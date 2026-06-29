let { BuildSpec, Local, OutputData, OutputBin, .. } = import "minimal.ncl" in
# R4a PROBE — stage0-tcc-0.9.27-musl.  Builds the musl-RELINK tcc (R3's tcc-0.9.27 source + the
# [R5 amd64 static-GOT fix] in tccelf.c: fill_got BEFORE tidy_section_headers) with tcc-0.9.26 (R2),
# baking MUSL prefixes (R4 crt+libc at /usr/lib, headers at /usr/include) instead of mes.  Then it
# SELF-TESTS on real amd64: links trivial+hello programs against R4 musl, RUNS them, and uses a pure
# -python ELF inspector (no binutils in the closure yet — that's R5) to dump the .got + check main's
# GOT slot.  This is the CS ground-truth for "is the static-link segfault REAL on amd64 or a Rosetta
# artifact" + "does the GOT fix work on real silicon".  set +e / exit 0 -> always reports.
#
# NOT trust-grade: tccsrc.tar.gz is the locally-patched source (provenance shortcut for the probe);
# the sealed R4a rung will apply the simple-patches at build time from the upstream sha-pinned tarball.
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in   # R2 — the compiler that builds tcc-musl
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in # R4 — SEALED musl libc.a + crt (the link target)
let stage0-mes = import "../stage0-mes/build.ncl" in            # R1 — mes headers (tcc-0.9.26 compiles tcc.c against these)
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-tcc-0.9.27-musl",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "tccsrc.tar.gz" } | Local,   # R3-patched tcc-0.9.27 source + the GOT fix
    stage0-tcc-r2,
    stage0-musl-r4,
    stage0-mes,
    bash,
    coreutils,
    tar,
    gzip,
    sed,
    grep,
    gawk-bootstrap,
  ],
  cmd = "./build.sh",
  outputs = {
    manifest = { glob = "usr/share/tcc-musl-probe/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-musl-probe/rows.log" } | OutputData,
    tcc = { glob = "usr/bin/tcc-musl", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec
