let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# R5 (stage0-binutils-2.30) — SKELETON / WIP 2026-06-26.
#
# The first rung to LINK real executables (as/ld/ar/nm/objcopy/objdump/strip) against R4's musl, built
# by R3's tcc-0.9.27. Model-B (ship all generated files; bedrock has no autoreconf/bison/flex/perl).
#
# ⚠️ UNRESOLVED: the tcc↔musl link bridge (R3 tcc bakes the mes crt prefix; binutils needs musl). See
#    .staging-ctx/bedrock-R5-binutils-status-2026-06-26.md and the WALL block in build.sh. This package
#    will NOT build green until that precursor (a musl-relinked tcc) lands + the GOTPCREL canary verdict.
let stage0-tcc-r3 = import "../stage0-tcc-0.9.27/build.ncl" in   # R3 — CC = tcc-0.9.27 (+ `tcc -ar`)
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in # R4 — SEALED musl libc.a + crt + headers (link target)
let bash = import "../bash/build.ncl" in                         # ./build.sh driver + configure shell
let make = import "../make/build.ncl" in                         # build engine
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in                             # binutils ships as .tar.xz (R4 was .gz)
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in     # configure's awk
let version = "2.30" in
{
  name = "stage0-binutils-2.30",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,
    # The 3 upstream patches are ALL Model-A-only NO-OPs — carried for provenance, intentionally NOT
    # applied on the Model-B path (build.sh does not patch). See pass1.sh src_prepare.
    { file = "libiberty-add-missing-config-directory-reference.patch" } | Local,
    { file = "new-gettext.patch" } | Local,
    { file = "opcodes-ensure-i386-init-dependencies-are-satisfied.patch" } | Local,
    {
      # upstream binutils 2.30 (.tar.xz), mirrored byte-identically (sha preserved). extract=false —
      # build.sh runs `tar -xf` (bash-build convention).
      url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
      sha256 = "6e46b8aeae2f727a36f0bd9505e405768a72218f1796f0d09757d45209871ae6",
      extract = false,
    } | Source,
    stage0-tcc-r3,    # R3: /usr/bin/tcc + /usr/lib/mes/**
    stage0-musl-r4,   # R4: /usr/lib/{libc.a,crt1.o,crti.o,crtn.o} + /usr/include/** (the link target)
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    xz,
    gawk-bootstrap,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # the binutils tools R6 (gcc-4.0.4) needs on PATH (env sets no AR/RANLIB -> R5 must seal first):
    bin = { glob = "usr/bin/*" } | OutputData,
    # the static libs other rungs may link (libbfd.a / libopcodes.a / libiberty.a):
    libs = { glob = "usr/lib/*.a" } | OutputLib,
    headers = { glob = "usr/include/**" } | OutputData,
  },
} | BuildSpec
