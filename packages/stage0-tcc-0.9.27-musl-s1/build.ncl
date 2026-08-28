let { Attrs, BuildSpec, Local, OutputBin, OutputLib, OutputData, .. } = import "minimal.ncl" in
# R4a STAGE 1 — stage0-tcc-0.9.27-musl-s1.  Builds the GOT-fixed tcc-0.9.27 (fill_got before
# tidy_section_headers) in a CLEAN MES env: deps are R2 (tcc-0.9.26) + R1 (mes) ONLY — NO R4 (musl), so
# /usr/include is pure mes (no R1/R4 header collision that crashed the single-package probe). tcc-0.9.26
# compiles tcc.c vs mes headers (R3's exact -I) and links it vs mes crt (CONFIG carried by tcc-0.9.26 =
# /usr/lib/mes; mes crt = PC32, no GOTPCREL → links fine WITHOUT the GOT fix).  The OUTPUT tcc bakes MUSL
# prefixes (/usr/lib, /usr/include) and carries the GOT fix in its linker, for stage 2 to exercise vs R4.
# Result: a STATIC mes-linked, self-contained tcc-musl (runs anywhere) + an x86_64 libtcc1.a.
#
# NOT trust-grade (overlay-iterated, locally-patched tccsrc.tar.gz). See [[bedrock-r5-binutils-link-wall]].
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in   # R2 — the compiler (mes-linked) that builds tcc-musl
let stage0-mes = import "../stage0-mes/build.ncl" in            # R1 — mes headers + mes crt/libc the build links against
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-tcc-0.9.27-musl-s1",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "tccsrc.tar.gz" } | Local,   # R3-patched tcc-0.9.27 source + the GOT fix
    stage0-tcc-r2,
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
    tcc = { glob = "usr/bin/tcc-musl", allow_missing_interpreter = true } | OutputBin,
    libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib,
    manifest = { glob = "usr/share/tcc-musl-s1/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-musl-s1/rows.log" } | OutputData,
  },
} | BuildSpec
