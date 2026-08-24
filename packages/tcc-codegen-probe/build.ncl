let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────────────
# tcc-codegen-probe — the standing codegen-bug rapid-isolation harness (DRAFT 2026-06-30).
# Component (a) of the toolkit: a guaranteed-DONE probe (like tcc-0.9.27-diag) that runs the reproducer
# LIBRARY (repro.tar.gz, component (b)) against the SEALED tcc-musl2 the way R5+ invoke it, and reports
# compile-rc / link-rc / run-rc / output-vs-expected per case, saving failing objects for objdump.
#
# Consumes the s4-SEALED tcc-musl2 (musl-linked/stable → NO mes-libc lottery → every FAIL is a REAL,
# deterministic codegen bug). Clean MUSL env: deps R4 (musl crt/libc/headers) + s4 (tcc-musl2 + libtcc1.a)
# ONLY — no R1, so /usr/include stays pure musl, exactly like s3/s4 and like R5+ at link time.
#
# PROBE not a rung: build.sh is set +e, never aborts, ALWAYS exits 0 with greppable rows + OutputData.
# A FAIL row does NOT fail the build (it is a finding, not an error) — this is intentional: the probe must
# always ship its results. (The s4 GATE is the fail-shut seal; this is the investigation instrument.)
# ─────────────────────────────────────────────────────────────────────────────────────────────────────
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in            # musl: libc.a + crt + headers
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in # tcc-musl2 (SEALED) + libtcc1.a
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let grep = import "../grep/build.ncl" in
let sed = import "../sed/build.ncl" in
{
  name = "tcc-codegen-probe",
  build_deps = [
    { file = "build.sh" } | Local,
    # the reproducer LIBRARY: repro/<name>.c [+ <name>.lib.c] + <name>.expected. Grows over time; seeded
    # from the s4 torture suite + the s2a..s2i isolation battery + the anticipated binutils/gcc shapes.
    { file = "repro.tar.gz" } | Local,
    stage0-musl-r4,
    stage0-tcc-musl-s4,
    bash,
    coreutils,
    tar,
    gzip,
    grep,
    sed,
  ],
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  # every OutputData glob MUST match >=1 file or minimal marks the build FAILED. All guaranteed on a full
  # run by build.sh's t=0 pre-population: MANIFEST.txt + rows.log + FAIL-INDEX.txt + saved-artifacts.tgz.
  outputs = {
    manifest = { glob = "usr/share/tcc-codegen-probe/MANIFEST.txt" } | OutputData,
    rows = { glob = "usr/share/tcc-codegen-probe/rows.log" } | OutputData,
    failindex = { glob = "usr/share/tcc-codegen-probe/FAIL-INDEX.txt" } | OutputData,
    saved = { glob = "usr/share/tcc-codegen-probe/saved-artifacts.tgz" } | OutputData,
  },
} | BuildSpec
