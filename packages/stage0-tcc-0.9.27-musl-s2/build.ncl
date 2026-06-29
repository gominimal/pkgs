let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
# R4a STAGE 2 — stage0-tcc-0.9.27-musl-s2.  THE VERDICT: does the GOT-fixed tcc-musl (from s1) link a
# RUNNING musl binary on real amd64?  CLEAN MUSL env: deps are R4 (sealed musl: crt+libc at /usr/lib,
# headers at /usr/include) + s1 (the static mes-linked, GOT-fixed tcc-musl + libtcc1.a) ONLY — NO R1, so
# /usr/include is pure musl (no header collision).  s1's tcc-musl is static/self-contained so it runs here
# despite no mes libc.  It compiles+links ret42/hello against R4 musl and RUNS them (built/ran over 8
# tries; tcc-musl is mes-linked so it's lottery-prone — retries). A custom-_start variant isolates layer-2
# (musl startup) from the linker/GOT/codegen, unconfounded on real amd64 (unlike the Rosetta version).
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in   # R4 — sealed musl (the link target)
let stage0-tcc-musl-s1 = import "../stage0-tcc-0.9.27-musl-s1/build.ncl" in  # s1 — the GOT-fixed tcc-musl + libtcc1.a
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-tcc-0.9.27-musl-s2",
  build_deps = [
    { file = "build.sh" } | Local,
    stage0-musl-r4,
    stage0-tcc-musl-s1,
    bash,
    coreutils,
    sed,
    grep,
    gawk-bootstrap,
  ],
  cmd = "./build.sh",
  outputs = {
    manifest = { glob = "usr/share/tcc-musl-s2/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-musl-s2/rows.log" } | OutputData,
  },
} | BuildSpec
