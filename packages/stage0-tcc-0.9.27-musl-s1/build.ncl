let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# R4a STAGE 1 — stage0-tcc-0.9.27-musl-s1.  Builds the GOT-fixed tcc-0.9.27 (fill_got before
# tidy_section_headers) in a CLEAN MES env: deps are R2 (tcc-0.9.26) + R1 (mes) ONLY — NO R4 (musl), so
# /usr/include is pure mes (no R1/R4 header collision that crashed the single-package probe). tcc-0.9.26
# compiles tcc.c vs mes headers (R3's exact -I) and links it vs mes crt (CONFIG carried by tcc-0.9.26 =
# /usr/lib/mes; mes crt = PC32, no GOTPCREL → links fine WITHOUT the GOT fix).  The OUTPUT tcc bakes MUSL
# prefixes (/usr/lib, /usr/include) and carries the GOT fix in its linker, for stage 2 to exercise vs R4.
# Result: a STATIC mes-linked, self-contained tcc-musl (runs anywhere) + an x86_64 libtcc1.a.
#
# NOT trust-grade (overlay-iterated, locally-patched tccsrc.tar.gz). See [[bedrock-r5-binutils-link-wall]].
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in # R2 — the compiler (mes-linked) that builds tcc-musl
let stage0-mes = import "../stage0-mes/build.ncl" in # R1 — mes headers + mes crt/libc the build links against
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let amd64_spec =
  {
    name = "stage0-tcc-0.9.27-musl-s1",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # R3-patched tcc-0.9.27 source + the GOT fix.  Was an in-repo blob; now a sha-pinned
        # staged Source (CI cannot lint binary Locals, and pinning belongs in the mirror).
        # Derivation note: tcc-0.9.27 upstream + the R3 patch set + the GOT fix — expressing
        # this as pristine-source+patches is a recorded follow-up.
        url = "gs://minimal-staging-archives/tccsrc-r3got-s1.tar.gz",
        sha256 = "f04ba1598543f3f09a0f0b95c9804e00ee7dc5eacfdacf159d6850873eeee3e9",
        extract = false,
      } | Source,
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
in
# ARCH SCOPE (buildbot builds every member on BOTH arches): this rung exists on
# amd64 only — it belongs to the hex0-rooted amd64 bootstrap ladder. arm64's
# equivalents are the SEALED bedrock artifacts consumed as sha-pinned Sources
# by the flip specs (#631/#667), so on arm64 this spec collapses to an
# explicitly-EMPTY collection: no build runs, nothing ships, and nothing on the
# arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27-musl-s1",
      build_deps = [],
    } | BuildSpec,
} target
