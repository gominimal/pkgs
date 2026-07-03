let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B4 — glibc-bedrock-2.42  ★ THE COLD FIRST-GLIBC ★  (scaffolded 2026-07-02)
# The seed-rooted, from-source build of the EXACT glibc-2.42 minimal's production stdenv ships
# (packages/glibc, same source + sha) — but built by the bedrock toolchain (R12 gcc-15.2.0,
# R10 binutils-2.41, R7 musl as BUILD_CC, R8 gmp/mpfr/mpc), NOT the debian-prebuilt seed.
#
# This is NOT a patch to production packages/glibc/build.sh (that 38-line file is the STEP-5
# native-rebuild shape: glibc already in /usr, ./configure && make).  A cold first-glibc needs the
# crosstool-NG / cross-LFS headers-first dance production never needed:
#   * a cross TRIPLE (build != host, same cpu/os/ABI) so configure sets cross_compiling=yes and
#     skips the AC_TRY_RUN target-binary probes that would wedge with no target libc present, while
#     staying a genuinely NATIVE x86_64 glibc (identical sysdeps selection);
#   * PASS 1 = install glibc headers + csu crt + a stub libc.so into a build-time DESTDIR sysroot;
#   * PASS 2 = OPTIONAL libgcc-vs-glibc rebuild (default SKIP — gated on B4_REBUILD_LIBGCC / the
#     coupling probe; x86_64 libgcc is libc-agnostic arithmetic + native TLS so probably ABI-safe);
#   * PASS 3 = glibc FINAL (production step-5 shape, ABI flags verbatim) -> $OUTPUT_DIR.
#
# NO glibc self-import and NO replace_on_cycle: cold from-source is the ENTIRE POINT of B4.
# See .staging-ctx/b4-glibc-recipe-design-2026-07-03.md for the full rationale + risk register.
# ============================================================================================
# ── seed-rooted toolchain (replaces production gcc/binutils/glibc/linux_headers) ──
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC/CXX (the exact prod gcc-15.2.0, musl-linked, --disable-shared)
let stage0-binutils = import "../stage0-binutils-2.41/build.ncl" in # R10: as/ld/ar/ranlib (glibc-2.42 needs binutils>=2.39)
let stage0-linux-headers = import "../stage0-linux-headers-6.12.43/build.ncl" in # kernel UAPI at /usr/include/{linux,asm,asm-generic}
let stage0-musl = import "../stage0-musl-1.2.5/build.ncl" in # R7: /usr/lib/musl-bedrock-1.2.5 — CC's OWN libc, BUILD_CC only (never the target)
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # R8: /usr/lib/gcc-math — consumed ONLY if Pass 2 runs
# ── base leaves (the PROVEN glibc-2.42 build tool set from production packages/glibc/build.ncl) ──
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in # FULL gawk (gen-tunables.awk / gen-sorted.awk / errlist.awk) — NOT gawk-bootstrap
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in # 4.4.1 == INSTALL newest-verified
let perl = import "../perl/build.ncl" in # tests/mtrace parity only; NOT build-required
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# ── other configure critic_missing hard-abort tools ──
let bison = import "../bison/build.ncl" in # intl/plural.c NOT shipped in the 2.42 tarball -> bison ALWAYS regenerates it
let m4 = import "../m4/build.ncl" in # bison runtime dep
let python = import "../python/build.ncl" in # gen-as-const.py orchestration (constants are CC-derived)
let version = "2.42" in

# outputs — model on production glibc/build.ncl all_outputs so the SEALED /usr artifact can byte-match
# the prebuilt glibc leaf at B7 (ships to plain /usr, --prefix=/usr, libc_cv_slibdir=/usr/lib, interp
# /lib64/ld-linux-x86-64.so.2 — do NOT ship under the versioned subdir).  PLUS two ADDITIONAL globs for
# the single-writer versioned sysroot B5 consumes -nostdinc (mirrors R7 musl's sysroot_inc/sysroot_lib).
let all_outputs = {
  # A few binaries (xtrace, ldd) depend on bash; omitted as a dep given how low-level glibc is.
  bins = { glob = "usr/bin/**", allow_missing_interpreter = true } | OutputBin,
  sbins = { glob = "usr/sbin/**" } | OutputBin,
  etc = { glob = "etc/**/*" } | OutputData,

  libs = { glob = "usr/lib/*.{so*,a}", allow_data = true } | OutputLib, # libc.so is a linker script, not an ELF binary
  crts = { glob = "usr/lib/{crt,gcrt,grcrt,Mcrt,rcrt,Scrt}*.o" } | OutputLib,
  lib_audit = { glob = "usr/lib/audit/*.so*" } | OutputLib,
  lib_locale = { glob = "usr/lib/locale/**" } | OutputData,
  lib_gconv = { glob = "usr/lib/gconv/**", allow_data = true } | OutputLib,

  libexec_getconf = { glob = "usr/libexec/getconf/**" } | OutputLib,

  i18n = { glob = "usr/share/i18n/**" } | OutputData,
  locales = { glob = "usr/share/locale/**" } | OutputData,

  includes = { glob = "usr/include/**" } | OutputData,

  # ★ single-writer VERSIONED sysroot (anti /usr coin-flip; see minimal_rootfs_nondeterministic_pollution).
  #   The single-level usr/lib/*.{so,a} globs above do NOT match this nested path (literal_separator), so
  #   it is not double-captured.  libc.so is a linker SCRIPT -> allow_data on sysroot_lib.
  sysroot_lib = { glob = "usr/lib/glibc-bedrock-2.42/lib/**", allow_data = true } | OutputLib,
  sysroot_include = { glob = "usr/lib/glibc-bedrock-2.42/include/**" } | OutputData,
}
in
{
  name = "glibc-bedrock-2.42",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # PRODUCTION glibc-2.42 tarball — SAME source + sha as minimal's packages/glibc (byte-identical
      # mirror; sha preserved -> sha-pinned resolvedDeps).  Already mirrored.  Downloadable from:
      # https://ftp.gnu.org/gnu/glibc/ .  extract=false (build.sh untars with --no-same-owner).
      url = "gs://minimal-staging-archives/glibc-%{version}.tar.xz",
      sha256 = "d1775e32e4628e64ef930f435b67bb63af7599acb6be2b335b9f19f16509f17f",
      extract = false,
    } | Source,
    {
      # gcc-15.2.0 FULL tarball — REQUIRED ONLY for the OPTIONAL Pass-2 libgcc rebuild (B4_REBUILD_LIBGCC=1).
      # SAME source + sha as R12 (stage0-gcc-15.2.0).  build.sh only untars it inside the Pass-2 `if` block,
      # so with the DEFAULT skip posture it is fetched-but-unused (cheap).  Declared here so the recipe is
      # complete for BOTH postures without a re-stage.  ⚠ stage_internal_deps_gap: `orch stage` captures only
      # the FIRST Source into manifest.json — this SECOND Source is hydrated by builder graph-traversal, NOT
      # the queue task's audit chain.  extract=false.  (GCC version hardcoded to match R12 / build.sh GCCVER.)
      url = "gs://minimal-staging-archives/gcc-15.2.0.tar.xz",
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e",
      extract = false,
    } | Source,
    # seed-rooted toolchain
    stage0-gcc,
    stage0-binutils,
    stage0-linux-headers,
    stage0-musl,
    stage0-gmp-mpfr-mpc,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # other
    bison,
    m4,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = all_outputs,
  attrs =
    {
      upstream_version = version,
      repology_project = "glibc",
      source_provenance = {
        category = 'GnuProject,
        name = "glibc",
      },
    } | Attrs,
} | BuildSpec
