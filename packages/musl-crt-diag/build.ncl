let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# musl-crt-diag — PIN why tcc-0.9.27 segfaults compiling musl's crt/crt1.c (the R4 wall). R4 cleared
# all scaffolding + 2 amd64 crt patches (skip-pic-crt, drop-dynamic-crt) but `tcc -c crt1.c` STILL
# SIGSEGVs — the FIRST musl object. The _DYNAMIC-lea guess was WRONG (patch applied, still crashes), so
# this probe STOPS guessing: it replays R4's exact extract/patch/configure, then runs `tcc -c crt1.c`
# (a) under the in-enclave ptrace tracer → backtrace (WHERE in tcc: assembler? codegen? parser?), and
# (b) through a bisection — asm-only vs C-only vs minimal — to pin the crashing construct. Then a
# targeted patch. Reuses the tcc-boot0-diag/tcc-0.9.27-diag tracer pattern (the keystone diagnostic).
#
# Probe, not a trust rung: bash + set +e, never aborts, ALWAYS exits 0 with greppable rows + OutputData.
# Pins are the EXACT R4 deps/patches/source so the crash reproduces faithfully.
let stage0-tcc-r3 = import "../stage0-tcc-0.9.27/build.ncl" in # R3 — tcc-0.9.27 (the compiler under test = CC)
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in # R4 — SEALED musl libc.a + crt at /usr/lib (R5 link canary)
let stage0-mes = import "../stage0-mes/build.ncl" in # R1 — mes headers for configure probes
let bash = import "../bash/build.ncl" in # ./build.sh driver + the configure shell
let make = import "../make/build.ncl" in # configure invokes it (we stop before the full make)
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let patch = import "../patch/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let version = "1.1.24" in
{
  name = "musl-crt-diag",
  build_deps = [
    { file = "build.sh" } | Local,
    # the EXACT R4 patches (so crt1.c is in its post-fix state — the probe diagnoses the REMAINING crash):
    { file = "makefile.patch" } | Local,
    { file = "madvise_preserve_errno.patch" } | Local,
    { file = "avoid_sys_clone.patch" } | Local,
    { file = "disable_ctype_headers.patch" } | Local,
    { file = "skip-pic-crt.patch" } | Local,
    { file = "drop-dynamic-crt.patch" } | Local,
    { file = "amd64-va-list.patch" } | Local,
    { file = "amd64-syscall-arch.patch" } | Local, # v12: validated register-var->movq fix for the linux/ syscall cluster
    {
      url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
      sha256 = "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3",
      extract = false,
    } | Source,
    stage0-tcc-r3,
    stage0-musl-r4, # R4: /usr/lib/{libc.a,crt1.o,crti.o,crtn.o} + /usr/include/** (the R5 static-link target)
    stage0-mes,
    bash,
    make,
    sed,
    grep,
    patch,
    coreutils,
    tar,
    gzip,
    gawk-bootstrap,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    manifest = { glob = "usr/share/musl-crt-diag/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/musl-crt-diag/*.log" } | OutputData,
    binaries = { glob = "usr/share/musl-crt-diag/tcc-*" } | OutputData,
  },
} | BuildSpec
