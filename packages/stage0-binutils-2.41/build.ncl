let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R10 — stage0-binutils-2.41.  A MODERN assembler/linker (as/ld/ar/nm/objcopy/objdump/ranlib/
# readelf/strip), built BY the from-source gcc-4.7.4 (R9), linked static against musl-1.2.5 (R7).
# The gcc-built analog of R5 (stage0-binutils-2.30, which was built by tcc): so it DROPS all the
# tcc-isms — no @PLT strip, no asm-rm, `ar`/`ranlib` are real binutils (R5) not `tcc -ar`, and the
# CC is the gcc-cc libc-using WRAPPER (copied from R9), not a musl-relinked tcc.
#
# CC / CXX = the gcc-cc + gcc-cxx WRAPPERS over R9's gcc-4.7.4/g++, forced onto R7's clean sysroot
#   /usr/lib/musl-bedrock-1.2.5 (`-nostdinc -isystem <gcc-freestanding> -isystem $SR/include` on
#   compile; `-B/-L $SR/lib -static` on link).  gmp/mpfr/mpc (R8) are NOT needed — binutils has no
#   bignum middle-end.  as/ld/ar/ranlib for R9's gcc to *assemble+archive* its output come from R5
#   (binutils-2.30) on PATH — see the ⚠ note below; this is the dep the ladder task list omitted.
#
# ── build.sh shape (adapt R5's binutils recipe + R9's gcc-cc wrapper) ────────────────────────
#   * top-level OUT-OF-TREE configure (2.41 has a real top-level `configure`; R5 hand-looped subdirs
#     only because tcc + i386 opcodes made the top-level path fragile — gcc doesn't need that).
#   * --disable-shared --disable-nls --disable-werror --disable-gold --disable-gprofng
#     --disable-plugins --enable-deterministic-archives --enable-64-bit-bfd --enable-install-libbfd
#   * config.sub is 2023-06-23 → knows x86_64-linux-{gnu,musl} natively → NO donor swap (unlike the
#     hand-swapped early rungs).
#   * Model-B: ship every generated file; mtime-guard newest + LOUD regen stubs (bison/flex/perl/
#     pod2man) so an accidental parser/man regen names itself instead of silently clobbering.
#   * install via DESTDIR=$OUTPUT_DIR with --prefix=/usr (as/ld BAKE their prefix → it MUST be the
#     final /usr, NOT a $BUILDROOT staging dir).  Then `rm -f usr/lib/*.la`.  See the findings doc:
#     the R8 "writable-staging-prefix" idiom does NOT transfer to a rung that installs prefix-baking
#     BINARIES — it is only for library-only rungs whose deps' installed .la are read at build time.
# ============================================================================================
let stage0-gcc-474 = import "../stage0-gcc-4.7.4/build.ncl" in       # R9: CC/CXX (gcc-4.7.4 / g++ via the gcc-cc wrapper)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # R5: as/ld/ar/ranlib on PATH — R9's gcc SHELLS OUT to these to assemble/archive its output
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in      # R7: /usr/lib/musl-bedrock-1.2.5 sysroot (static link libc + crt + headers)
let bash = import "../bash/build.ncl" in                            # ./build.sh driver + configure shell
let make = import "../make/build.ncl" in                            # build engine
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in                                # binutils-2.41 ships as .tar.xz
let diffutils = import "../diffutils/build.ncl" in                  # configure's cmp/diff (R8 saw them missing)
let findutils = import "../findutils/build.ncl" in                  # Model-B mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in        # configure's awk
let version = "2.41" in
{
  name = "stage0-binutils-2.41",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local,   # record-at-pin-time byte-identity seal (UNPINNED placeholder)
    {
      # upstream binutils 2.41 (.tar.xz), mirrored byte-identically (sha preserved -> sha-pinned
      # resolvedDeps).  extract=false — build.sh runs `tar --no-same-owner -xf` (bedrock convention).
      url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
      sha256 = "ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450",
      extract = false,
    } | Source,
    stage0-gcc-474,        # R9: CC (gcc-4.7.4) + CXX (g++) via the gcc-cc/gcc-cxx wrappers
    stage0-binutils-r5,    # R5: /usr/bin/{as,ld,ar,ranlib} — R9's gcc invokes these; env sets no system AR/RANLIB
    stage0-musl-r7,        # R7: /usr/lib/musl-bedrock-1.2.5 (libc.a + crt*.o + headers)
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
    # the deliverable binutils tools (R11 gcc-10.5.0 needs a MODERN as/ld on PATH; env sets no AR/RANLIB):
    # as ld ar nm objcopy objdump ranlib readelf strip + addr2line c++filt size strings + the triplet symlinks
    bin = { glob = "usr/bin/*" } | OutputData,
    # the static libs downstream rungs may link (libbfd.a / libopcodes.a / libctf.a / libsframe.a / libiberty.a):
    libs = { glob = "usr/lib/*.a" } | OutputLib,
    # bfd.h / ansidecl.h / etc (installed by --enable-install-libbfd):
    headers = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "binutils",
    } | Attrs,
} | BuildSpec
