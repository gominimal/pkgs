let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B5 — binutils-2.46-glibc  ★ THE GLIBC-LINKED ASSEMBLER/LINKER ★  (REVIEW-READY scaffold 2026-07-03)
# The from-source, GLIBC-LINKED build of the EXACT binutils-2.46.0 minimal's production stdenv ships
# (packages/binutils, same source + sha) — assembled/linked by the bedrock toolchain (R12 gcc-15.2.0
# musl-linked driver, R10 binutils-2.41 as the bootstrapping as/ld) but targeting the from-source
# glibc-2.42 (B4 = glibc-bedrock-2.42), so the produced as/ld/ar/... are glibc-dynamic (interp
# /lib64/ld-linux-x86-64.so.2) with a shared libbfd.so — the ABI-matched twin of production binutils.
#
# This is the NEW recipe the B5 rung needs: only stage0-binutils-2.30 (R5, tcc-built) and
# stage0-binutils-2.41 (R10, gcc-4.7.4-built, musl-static) existed — neither is 2.46 nor glibc-linked.
# Template = stage0-binutils-2.41/build.sh, flipped musl->glibc + version 2.41->2.46.0 + the stage0
# static/minimal config set -> PRODUCTION packages/binutils/build.sh flags.
#
# ── R10(musl,static,2.41) -> B5(glibc,shared,2.46.0) DELTA ────────────────────────────────────
#   1. SR swap:  /usr/lib/musl-bedrock-1.2.5  ->  /usr/lib/glibc-bedrock-2.42  (B4's versioned sysroot;
#      UAPI linux/asm co-located there, so -isystem $SR/include is self-contained).
#   2. Host wrappers DROP `-static` (glibc is dynamic).  binutils is C-only once gold/gprofng are off,
#      so there is NO musl-libstdc++/glibc mixing hazard (unlike the gcc twin) — the C++ wrapper only
#      ever serves the top-level AC_PROG_CXX probe.
#   3. HOSTCFLAGS: DROP the gcc-4.7 `-std=gnu99 -fgnu89-inline` dialect workaround (R12 gcc-15 is modern
#      C) and adopt PRODUCTION determinism flags (-march=x86-64-v3 -O3 -pipe -gno-record-gcc-switches
#      -ffile-prefix-map).
#   4. Config flags: DROP the stage0 `--disable-shared --disable-plugins --with-sysroot=` minimal set;
#      adopt PRODUCTION: --enable-ld=default --enable-plugins --enable-shared --enable-new-dtags
#      --enable-default-hash-style=gnu --enable-deterministic-archives --sysconfdir=/etc, `make
#      tooldir=/usr`, `install-strip`.  KEEP --disable-gold --disable-gprofng (C++ subdirs -> would
#      reintroduce the musl-libstdc++ mixing; default ld is ld.bfd, exactly production's --enable-ld=
#      default choice, so the 368 pkgs are unaffected).  See readiness note DIVERGENCES.
#   5. --with-system-zlib OMITTED (production passes it, but there is no seed-rooted bedrock zlib yet;
#      binutils' BUNDLED zlib is used instead — affects only compressed-debug/.gnu_debuglink, not ABI).
# ============================================================================================
# ── seed-rooted toolchain ──
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # R12: CC (the exact prod gcc-15.2.0, musl-linked driver) — emits glibc output via -B/-L/-isystem $SR
let stage0-binutils-r10 = import "../stage0-binutils-2.41/build.ncl" in # R10: as/ld/ar/ranlib on PATH — R12's gcc SHELLS OUT to these to assemble/archive
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: /usr/lib/glibc-bedrock-2.42 versioned sysroot (the TARGET libc; UAPI co-located)
# ── base leaves (the R10 build tool set) ──
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # binutils-2.46.0 ships as .tar.xz
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let findutils = import "../findutils/build.ncl" in # Model-B mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
let version = "2.46.0" in
{
  name = "binutils-2.46-glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local, # NO byte-seal at B5 by design (different compiler than the prebuilt); functional-anchor placeholder
    {
      # PRODUCTION binutils-2.46.0 tarball — SAME source + sha as minimal's packages/binutils (already
      # mirrored byte-identically; sha preserved -> sha-pinned resolvedDeps).  MIRROR-FIRST: no new
      # upload needed — this is the exact slot production/packages/binutils/build.ncl already fetches.
      # extract=false — build.sh runs `tar --no-same-owner -xf` (bedrock convention).
      url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
      sha256 = "d75a94f4d73e7a4086f7513e67e439e8fcdcbb726ffe63f4661744e6256b2cf2",
      extract = false,
    } | Source,
    stage0-gcc, # R12: CC via the gcc-cc wrapper (glibc-targeted, no -static)
    stage0-binutils-r10, # R10: /usr/bin/{as,ld,ar,ranlib} — R12's gcc invokes these to assemble/archive
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
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # the deliverable glibc-linked binutils tools (as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip +
    # addr2line/c++filt/size/strings + the x86_64-linux-gnu-<tool> triplet symlinks):
    bin = { glob = "usr/bin/*" } | OutputData,
    # shared + static libs (libbfd.so*/libopcodes.so* from --enable-shared, plus the .a):
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    # bfd-plugins dir (--enable-plugins) + ldscripts:
    bfdplugins = { glob = "usr/lib/bfd-plugins/**" } | OutputLib,
    ldscripts = { glob = "usr/lib/ldscripts/*" } | OutputData,
    # bfd.h / ansidecl.h / etc:
    headers = { glob = "usr/include/**" } | OutputData,
    # NO etcs output: production's etc/* comes from gprofng (gprofng.rc), which we --disable-gprofng
    # (C++/musl-libstdc++ mixing avoidance) -> nothing lands under etc/ and an empty glob FAILS
    # enumeration ("output globs did not match any files: etcs", 2026-07-03).
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "binutils",
      source_provenance = {
        category = 'GnuProject,
        name = "binutils",
      },
    } | Attrs,
} | BuildSpec
