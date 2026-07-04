let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B5 sub-rung — gmp-glibc  ★ THE GLIBC-LINKED RUNTIME BIGNUM LIB ★  (scaffold 2026-07-04)
# The from-source, GLIBC-LINKED, SHARED build of the EXACT gmp-6.3.0 minimal's production stdenv
# ships (packages/gmp, same source + sha) — built by R12 (stage0-gcc-15.2.0, musl-linked driver,
# glibc-retargeted via the B5 wrapper), assembled/linked by the SEALED binutils-2.46-glibc (B5),
# against the SEALED glibc-bedrock-2.42 (B4).  Produces libgmp.so.10 — the RUNTIME lib production's
# toolchain closure dynamically links (cc1's bignum middle-end is a DIFFERENT consumer: it links R8's
# musl-static /usr/lib/gcc-math .a's; that rung stays untouched).
#
# WHY A SEPARATE PKG (not combined like R8 stage0-gmp-mpfr-mpc): production leaves are separate
# gmp/mpfr/mpc, EACH with its own replace_on_cycle prebuilt slot — the B7 flip swaps each slot for
# its bedrock twin 1:1.  A combined artifact would need a fan-out shim.  R8 was combined because its
# sole consumer (cc1) eats all three together at one --with-gmp path; runtime consumers link them
# individually (own sonames, own runtime_deps chains: mpfr→gmp, mpc→gmp+mpfr).
#
# ── production packages/gmp DELTA (the exact flips) ─────────────────────────────────────────
#   1. Toolchain: production binutils/gcc/glibc/linux_headers -> R12 gcc + B5 binutils + B4 glibc
#      (UAPI co-located in the B4 sysroot).  Base leaves trimmed to the proven B5 set (perl/file/
#      bzip2/gzip are gmp-build-inert; production carries them as stdenv boilerplate).
#   2. --disable-cxx (production: --enable-cxx).  R12's g++ only has its MUSL-built libstdc++.a;
#      linking that into a glibc-dynamic libgmpxx.so is the R4 silent-corruption mixing hazard.
#      libgmpxx has ~no consumers in the toolchain closure.  Revisit after gcc-15.2.0-glibc seals
#      (its glibc libstdc++.so makes --enable-cxx safe).  DIVERGENCE, documented in stage0.answers.
#   3. runtime_deps: glibc -> glibc-bedrock; DROP subsetOf gcc [libstdcpp, libgcc] (no C++; R12
#      links libgcc.a statically).
#   4. NO replace_on_cycle (bedrock rungs are cold-built by definition; production's gmp keeps its
#      prebuilt slot until the B7 flip points it at THIS artifact).
#   5. ADDITIONAL single-writer versioned tree /usr/lib/gmp-bedrock-6.3.0/{lib,include} so
#      mpfr-glibc/mpc-glibc consume gmp -nostdinc/-L-explicit, immune to the /usr coin flip
#      (minimal_rootfs_nondeterministic_pollution — same pattern as B4/R7 sysroots).
# ============================================================================================
# ── seed-rooted toolchain ──
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC (musl-linked gcc-15.2.0 driver) — emits glibc output via the wrapper
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # B5 (SEALED): as/ld/ar/ranlib on PATH — glibc-dynamic, interp baked to the B4 loader
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 (SEALED): /usr/lib/glibc-bedrock-2.42 versioned sysroot (target libc; UAPI co-located)
# ── base leaves (the proven B5 build tool set) ──
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # gmp-6.3.0 ships .tar.xz
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let findutils = import "../findutils/build.ncl" in # Model-B mtime guard: find -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
let m4 = import "../m4/build.ncl" in # gmp builds WITH assembly (production parity) -> m4 preprocesses the mpn .asm
let version = "6.3.0" in
{
  name = "gmp-glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local, # NO byte-seal at B5 by design; functional-anchor note
    {
      # PRODUCTION gmp-6.3.0 tarball — SAME slot + sha as packages/gmp/build.ncl (mirror-verified
      # 2026-07-04: sha256 matches the production pin byte-for-byte; no new upload).
      url = "gs://minimal-staging-archives/gmp-%{version}.tar.xz",
      sha256 = "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898",
      extract = false,
    } | Source,
    stage0-gcc, # R12: CC via the glibc-retargeted gcc-cc wrapper
    binutils-glibc, # B5: as/ld/ar/ranlib (the matched glibc-linked set)
    glibc-bedrock, # B4: the TARGET glibc sysroot
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
    m4,
  ],
  # production-parity runtime shape (packages/gmp has [glibc, subsetOf gcc [...]]; gcc-libs dropped —
  # see DELTA #3) so the B7 flip is a 1:1 leaf swap:
  runtime_deps = [
    glibc-bedrock,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # ── production-parity /usr tree (packages/gmp/build.ncl globs verbatim) ──
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib, # libgmp.so* (shared-only; the {a,...} alt is prod-glob parity)
    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData, # gmp.pc (no gmpxx.pc: --disable-cxx; dir-glob stays non-empty)
    infos = { glob = "usr/share/info/*.info" } | OutputData, # shipped-in-tarball .info, mtime-guarded
    includes = { glob = "usr/include/**" } | OutputData, # gmp.h (no gmpxx.h: --disable-cxx)

    # ★ single-writer versioned tree for the bedrock consumers (mpfr-glibc/mpc-glibc); the
    #   single-level usr/lib/* globs above do NOT match this nested path (literal_separator):
    sysroot_lib = { glob = "usr/lib/gmp-bedrock-%{version}/lib/**" } | OutputLib,
    sysroot_include = { glob = "usr/lib/gmp-bedrock-%{version}/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gmp",
      source_provenance = {
        category = 'GnuProject,
        name = "gmp",
      },
    } | Attrs,
} | BuildSpec
