let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B5 sub-rung — mpc-glibc  ★ THE GLIBC-LINKED RUNTIME COMPLEX LIB ★  (scaffold 2026-07-04)
# From-source, GLIBC-LINKED, SHARED mpc-1.4.0 (libmpc.so.3) — the EXACT production packages/mpc
# source + sha, built by R12 through the B5 glibc-retargeting wrapper against sealed B4 glibc +
# sealed binutils-2.46-glibc, linked against the sibling gmp-glibc + mpfr-glibc via their
# single-writer versioned trees.  Terminal leaf of the gmp -> mpfr -> mpc chain.
#
# Separate pkg (not combined): mirrors production's leaf shape 1:1 for the B7 replace_on_cycle flip —
# see gmp-glibc/build.ncl for the full rationale.
#
# ── production packages/mpc DELTA ──
#   1. Toolchain swap (prod binutils/gcc/glibc/linux_headers -> R12 + B5-binutils + B4); lean B5 leaves.
#   2. gmp/mpfr via --with-{gmp,mpfr}-{lib,include} at the versioned trees; LDFLAGS bakes JOINED
#      -Wl,-rpath entries for both (walls #1/#3/#4).  ALSO listed in build_deps explicitly (production
#      only carries them as runtime_deps and leans on sandbox hydration; explicit is single-writer-safe).
#   3. runtime_deps 1:1 with production's [glibc, gmp, mpfr] -> [glibc-bedrock, gmp-glibc, mpfr-glibc].
#   4. NO replace_on_cycle; ADDITIONAL /usr/lib/mpc-bedrock-1.4.0 single-writer tree (future bedrock
#      consumers, e.g. an eventual glibc-native gcc rebuild).
#   5. Fail-shut B5-MPC-GATE: complex mul (6+i)*(7+0i) link+RUN via explicit loader.
# ============================================================================================
# ── seed-rooted toolchain ──
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC via the glibc-retargeted wrapper
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # B5 (SEALED): as/ld/ar/ranlib
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 (SEALED): target glibc sysroot
let gmp-glibc = import "../gmp-glibc/build.ncl" in # sibling: /usr/lib/gmp-bedrock-6.3.0
let mpfr-glibc = import "../mpfr-glibc/build.ncl" in # sibling: /usr/lib/mpfr-bedrock-4.2.2
# ── base leaves (the proven B5 build tool set) ──
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # mpc-1.4.0 mirrored as .tar.xz (production slot)
let diffutils = import "../diffutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let version = "1.4.0" in
{
  name = "mpc-glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,
    {
      # PRODUCTION mpc-1.4.0 tarball — SAME slot + sha as packages/mpc/build.ncl (mirror-verified
      # 2026-07-04: sha256 matches the production pin byte-for-byte; no new upload).
      url = "gs://minimal-staging-archives/mpc-%{version}.tar.xz",
      sha256 = "3210b3a546b1cb00c296ca360891d7740ee6ff06deb02a27a35b20cd3c0bb1a5",
      extract = false,
    } | Source,
    stage0-gcc,
    binutils-glibc,
    glibc-bedrock,
    gmp-glibc, # explicit (see DELTA #2)
    mpfr-glibc, # explicit (see DELTA #2)
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    xz,
    diffutils,
    findutils,
    gawk-bootstrap,
  ],
  # 1:1 with production packages/mpc runtime_deps = [glibc, gmp, mpfr]:
  runtime_deps = [
    glibc-bedrock,
    gmp-glibc,
    mpfr-glibc,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # ── production-parity /usr tree (packages/mpc/build.ncl globs verbatim) ──
    libs = { glob = "usr/lib/libmpc.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libmpc.la" } | OutputData,
    includes = { glob = "usr/include/mpc.h" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    # (no pkgconfigs: production mpc declares none.  NB mpc-1.4.0 DOES install mpc.pc — production
    # deliberately leaves it uncaptured; we match that shape 1:1 for the B7 flip.)

    # ★ single-writer versioned tree:
    sysroot_lib = { glob = "usr/lib/mpc-bedrock-%{version}/lib/**" } | OutputLib,
    sysroot_include = { glob = "usr/lib/mpc-bedrock-%{version}/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "mpc",
      source_provenance = {
        category = 'GnuProject,
        name = "mpc",
      },
    } | Attrs,
} | BuildSpec
