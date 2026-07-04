let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B5 sub-rung — mpfr-glibc  ★ THE GLIBC-LINKED RUNTIME FLOAT LIB ★  (scaffold 2026-07-04)
# From-source, GLIBC-LINKED, SHARED mpfr-4.2.2 (libmpfr.so.6) — the EXACT production packages/mpfr
# source + sha, built by R12 through the B5 glibc-retargeting wrapper against sealed B4 glibc +
# sealed binutils-2.46-glibc, linked against the sibling gmp-glibc (its single-writer
# /usr/lib/gmp-bedrock-6.3.0 tree; the /usr copy is coin-flip-exposed by principle, so we don't use it).
#
# Separate pkg (not combined): mirrors production's leaf shape 1:1 for the B7 replace_on_cycle flip —
# see gmp-glibc/build.ncl for the full rationale.  Build order gmp -> mpfr -> mpc = dep edges.
#
# ── production packages/mpfr DELTA ──
#   1. Toolchain swap (prod binutils/gcc/glibc/linux_headers -> R12 + B5-binutils + B4); lean B5 leaves.
#   2. gmp = gmp-glibc via --with-gmp-lib/--with-gmp-include at the versioned tree; LDFLAGS bakes
#      -Wl,-rpath,<gmp-bedrock>/lib so configure's RUN-tests (gmp.h-vs-libgmp version check) and the
#      installed libmpfr.so resolve libgmp WITHOUT /etc/ld.so.cache or a /lib64 (walls #1/#3).
#      DIVERGENCE: production libmpfr.so carries no RUNPATH; ours points at the versioned tree
#      (resolves in any sandbox that hydrates gmp-glibc).  Documented in stage0.answers.
#   3. runtime_deps glibc->glibc-bedrock, gmp->gmp-glibc (1:1 with production's [glibc, gmp]).
#   4. NO replace_on_cycle; ADDITIONAL /usr/lib/mpfr-bedrock-4.2.2 single-writer tree for mpc-glibc.
#   5. Fail-shut B5-MPFR-GATE exercising the FLOAT path (mpfr_set_d/mul) — the R4 lesson: float
#      correctness gates at the rung that builds the float lib, never deferred.
# ============================================================================================
# ── seed-rooted toolchain ──
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC via the glibc-retargeted wrapper
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # B5 (SEALED): as/ld/ar/ranlib
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 (SEALED): target glibc sysroot
let gmp-glibc = import "../gmp-glibc/build.ncl" in # sibling: /usr/lib/gmp-bedrock-6.3.0 (+ /usr parity)
# ── base leaves (the proven B5 build tool set) ──
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # mpfr-4.2.2 ships .tar.xz
let diffutils = import "../diffutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let version = "4.2.2" in
{
  name = "mpfr-glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,
    {
      # PRODUCTION mpfr-4.2.2 tarball — SAME slot + sha as packages/mpfr/build.ncl (mirror-verified
      # 2026-07-04: sha256 matches the production pin byte-for-byte; no new upload).
      url = "gs://minimal-staging-archives/mpfr-%{version}.tar.xz",
      sha256 = "b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01",
      extract = false,
    } | Source,
    stage0-gcc,
    binutils-glibc,
    glibc-bedrock,
    gmp-glibc, # the bignum base (link + headers via its gmp-bedrock versioned tree)
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
  # 1:1 with production packages/mpfr runtime_deps = [glibc, gmp]:
  runtime_deps = [
    glibc-bedrock,
    gmp-glibc,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # ── production-parity /usr tree (packages/mpfr/build.ncl globs verbatim) ──
    libs = { glob = "usr/lib/libmpfr.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libmpfr.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData, # mpfr.pc
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData, # mpfr.h + mpf2mpfr.h

    # ★ single-writer versioned tree for mpc-glibc:
    sysroot_lib = { glob = "usr/lib/mpfr-bedrock-%{version}/lib/**" } | OutputLib,
    sysroot_include = { glob = "usr/lib/mpfr-bedrock-%{version}/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "mpfr",
      source_provenance = {
        category = 'GnuProject,
        name = "mpfr",
      },
    } | Attrs,
} | BuildSpec
