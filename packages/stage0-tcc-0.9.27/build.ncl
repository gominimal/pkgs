let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-tcc-0.9.27: mainline tinycc 0.9.27 compiled in one shot by stage0-tcc-0.9.26's tcc
# against its mes-libc at /usr/lib/mes, then used (-c/-ar only) to rebuild mes-libc once more.
# Outputs /usr/bin/tcc + /usr/lib/mes/** for the musl rungs. No mescc and no boot loop.
# Driver: tcc.kaem (live-bootstrap steps/tcc-0.9.27/pass1.kaem with env/unpack/gate/staging
# adapted), run by /usr/bin/kaem --strict so any non-zero child aborts the build.
#
# Patch set relative to stage0-tcc-0.9.26: the mescc-codegen fixes (fix-shift/swapf/swapb/mul/
# vararg) and fix-plt are dropped, since tcc-0.9.26 is a correct compiler and tcc-0.9.27 links
# no executable here. fix-stdarg and fix-setjmp are reused on the freshly extracted mes-0.27.1.
# The remaining patches are upstream's tcc-0.9.27 set plus two amd64 float-constant fixes.
#
# /usr is mounted read-only; the build writes to /build/output/usr/**. Because tcc-0.9.27 is
# only used for -c/-ar here, the deliverable bakes the consumer /usr/lib/mes directly.
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in # tcc-0.9.26 + its rebuilt mes-libc at /usr/lib/mes
let stage0-mes = import "../stage0-mes/build.ncl" in # mes libc headers
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # kaem (driver), catm, simple-patch
let coreutils = import "../coreutils/build.ncl" in # cp, chmod, mkdir, sha256sum
let amd64_spec =
  {
    name = "stage0-tcc-0.9.27",
    build_deps = [
      { file = "tcc.kaem" } | Local, # the kaem driver
      { file = "stage0.answers" } | Local, # sha256sum -c byte-identity gate
      # tcctools.c: relocate the -ar archiver's fopen() (same pair as stage0-tcc-0.9.26):
      { file = "remove-fileopen.before" } | Local,
      { file = "remove-fileopen.after" } | Local,
      { file = "addback-fileopen.before" } | Local,
      { file = "addback-fileopen.after" } | Local,
      # tccelf.c: upstream's two fixes from steps/tcc-0.9.27/simple-patches:
      { file = "fiwix-paddr.before" } | Local,
      { file = "fiwix-paddr.after" } | Local,
      { file = "check-reloc-null.before" } | Local,
      { file = "check-reloc-null.after" } | Local,
      # upstream's three unified-diff patches from steps/tcc-0.9.27/patches, as simple-patch pairs.
      # ignore-static-inside-array is required to parse musl's `char buf[static N]` parameters.
      { file = "ignore-static-inside-array.before" } | Local,
      { file = "ignore-static-inside-array.after" } | Local,
      { file = "dont-skip-weak-symbols-ar.before" } | Local,
      { file = "dont-skip-weak-symbols-ar.after" } | Local,
      { file = "static-link.before" } | Local,
      { file = "static-link.after" } | Local,
      # tccgen.c amd64 float-constant fixes: tcc-0.9.26 folds -0.0 to NaN, so unary minus on a
      # float constant and signed-int-to-float casts are done without FP negation. Without them
      # a negated float literal in a static initializer is rejected as non-constant.
      { file = "neg-float-const.before" } | Local,
      { file = "neg-float-const.after" } | Local,
      { file = "cast-signed-direct.before" } | Local,
      { file = "cast-signed-direct.after" } | Local,
      # reused from stage0-tcc-0.9.26: mes stdarg.h -> SysV __builtin_va_* under __TINYC__ (mes's
      # header shadows tcc's own via -I include), and the basic-asm setjmp rewrite.
      { file = "fix-stdarg.before" } | Local,
      { file = "fix-stdarg.after" } | Local,
      { file = "fix-setjmp.before" } | Local,
      { file = "fix-setjmp.after" } | Local,
      {
        # mainline tinycc 0.9.27; sha from live-bootstrap steps/tcc-0.9.27/sources.
        # Extracts to /build/tcc-0.9.27/.
        url = "gs://minimal-staging-archives/tcc-0.9.27.tar.bz2",
        sha256 = "de23af78fca90ce32dff2dd45b3432b2334740bb9bb7b05bf60fdbfc396ceb9c",
        extract = true,
      } | Source,
      {
        # mes-0.27.1 source, re-extracted so tcc-0.9.27 rebuilds mes-libc. Same sha as the
        # stage0-mes Source. Extracts to /build/mes-0.27.1/.
        url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
        sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
        extract = true,
      } | Source,
      # toolchain suppliers (chain-enforce predecessor edges); build_deps are not transitively overlaid:
      stage0-tcc-r2, # /usr/bin/{tcc-0.9.26,tcc,...} + /usr/lib/mes/**
      stage0-mes, # /usr/include/** (mes libc headers for the tcc.c compile)
      stage0-mescc-full, # /usr/bin/{kaem,catm,simple-patch,...}
      coreutils, # /usr/bin/{cp,chmod,mkdir,sha256sum}
    ],
    # tcc-0.9.27 and the rebuilt mes-libc are static ELF (CONFIG_TCC_STATIC=1): no .interp, no DT_NEEDED.
    cmds = [
      ["/usr/bin/kaem", "--strict", "--verbose", "--file", "tcc.kaem"],
    ],
    outputs = {
      # the deliverable the musl rungs build with (consumer /usr/lib/mes baked in, see tcc.kaem)
      tcc = { glob = "usr/bin/tcc", allow_missing_interpreter = true } | OutputBin,
      tcc_ver = { glob = "usr/bin/tcc-0.9.27", allow_missing_interpreter = true } | OutputBin,
      # the tcc-0.9.27-rebuilt mes-libc (crt1.o, libc.a, libgetopt.a). crtn.o/crti.o are empty on
      # amd64; allow_data because empty .o files have no ELF magic.
      mes_libc = { glob = "usr/lib/mes/*.{a,o}", allow_data = true } | OutputLib,
      tcc_lib = { glob = "usr/lib/mes/tcc/libtcc1.a" } | OutputLib,
    },
    attrs =
      {
        upstream_version = "0.9.27",
        repology_project = "tinycc",
      } | Attrs,
  } | BuildSpec
in
# amd64 only: this rung belongs to the hex0-rooted amd64 ladder. On arm64 the spec collapses to
# an empty collection (no build, no outputs, nothing depends on it).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27",
      build_deps = [],
    } | BuildSpec,
} target
