let { BuildSpec, Local, OutputBin, OutputLib, OutputData, .. } = import "minimal.ncl" in
# R4a STAGE 3 — stage0-tcc-0.9.27-musl-s3.  The MUSL-RELINK (two-stage stability).  s1's tcc-musl is
# mes-linked -> flaky on big compiles/links (the mes-libc lottery).  Now that it LINKS running musl
# binaries (fixes A+B+C), have it rebuild tcc.c against MUSL -> tcc-musl2, a MUSL-LINKED tcc that escapes
# the mes-libc lottery (stable) and is the stress-test for the upcoming binutils build.  Clean MUSL env:
# deps R4 (musl) + s1 (the mes-linked tcc-musl + libtcc1.a) ONLY — no R1, so /usr/include is pure musl.
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in
let stage0-tcc-musl-s1 = import "../stage0-tcc-0.9.27-musl-s1/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-tcc-0.9.27-musl-s3",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "tccsrc.tar.gz" } | Local,   # tcc-0.9.27 + R3 patches + GOT fixes A,B,C
    stage0-musl-r4,
    stage0-tcc-musl-s1,
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
    tcc = { glob = "usr/bin/tcc-musl2", allow_missing_interpreter = true } | OutputBin,
    libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib,
    manifest = { glob = "usr/share/tcc-musl-s3/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-musl-s3/rows.log" } | OutputData,
  },
} | BuildSpec
