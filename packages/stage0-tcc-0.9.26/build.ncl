let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-tcc-0.9.26: janneke's tcc-0.9.26 fork compiled by MesCC (stage0-mes) against mes-libc,
# then bootstrapped tcc-mes -> tcc-boot0 -> boot1 -> boot2 -> /usr/bin/tcc. Also rebuilds mes-libc
# with tcc and ships it at /usr/lib/mes for stage0-tcc-0.9.27.
# Driver: tcc.kaem (live-bootstrap steps/tcc-0.9.26/pass1.kaem with env/unpack/gate/staging
# adapted), run by /usr/bin/kaem --strict so any non-zero child aborts the build.
#
# Toolchain comes whole from stage0-mescc-full (kaem, catm, M1, hex2, simple-patch, ...) and
# stage0-mes (mes-m2, mescc.scm, mes-libc, headers, Scheme module trees). build_deps are not
# transitively overlaid, so every tool supplier is listed explicitly.
# /usr is mounted read-only; the build writes to /build/output/usr/** and bakes the consumer
# /usr/lib/mes path into the deliverable tcc (see tcc.kaem).
# Any downstream spec importing this package must bind the dotted dir name to a dotless variable.
let stage0-mes = import "../stage0-mes/build.ncl" in # mes-m2, mescc.scm, mes-libc, headers, module trees
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # kaem (driver), catm, M1, hex2, M2-Mesoplanet, match, simple-patch, blood-elf
let coreutils = import "../coreutils/build.ncl" in # cp, chmod, mkdir, rm, sha256sum
let amd64_spec =
  {
    name = "stage0-tcc-0.9.26",
    build_deps = [
      { file = "tcc.kaem" } | Local, # the kaem driver
      { file = "stage0.answers" } | Local, # sha256sum -c byte-identity gate
      { file = "remove-fileopen.before" } | Local, # live-bootstrap simple-patch pair for tcctools.c
      { file = "remove-fileopen.after" } | Local,
      { file = "addback-fileopen.before" } | Local,
      { file = "addback-fileopen.after" } | Local,
      # gfunc_call: per-field SValue swap; mescc miscompiles the whole-struct copy and corrupts
      # the type of the 4th+ call argument.
      { file = "fix-swapf.before" } | Local,
      { file = "fix-swapf.after" } | Local,
      { file = "fix-swapb.before" } | Local,
      { file = "fix-swapb.after" } | Local,
      # tccelf.c: static links call defined symbols directly instead of through an unfilled PLT.
      # tccgen.c: disable the power-of-two strength reduction that mescc miscompiles.
      { file = "fix-plt.before" } | Local,
      { file = "fix-plt.after" } | Local,
      { file = "fix-mul.before" } | Local,
      { file = "fix-mul.after" } | Local,
      # mes-libc setjmp rewritten as basic asm; tcc-mes miscompiles the extended-asm output operand.
      { file = "fix-setjmp.before" } | Local,
      { file = "fix-setjmp.after" } | Local,
      # x86_64-gen.c variadic-call %al setup decomposed; mescc miscompiles the chained deref + ternary.
      { file = "fix-vararg.before" } | Local,
      { file = "fix-vararg.after" } | Local,
      # x86_64-gen.c gen_opi constant shift count decomposed; mescc collapses it to 0 (shl/shr $0).
      { file = "fix-shift.before" } | Local,
      { file = "fix-shift.after" } | Local,
      # mes stdarg.h: use tcc's SysV __builtin_va_* under __TINYC__; the stack-based va_list does
      # not match the SysV amd64 ABI tcc-mes emits.
      { file = "fix-stdarg.before" } | Local,
      { file = "fix-stdarg.after" } | Local,
      # simple-patch.c is not compiled here; /usr/bin/simple-patch comes from stage0-mescc-full.
      # Shipped only as a self-contained fallback source.
      { file = "simple-patch.c" } | Local,
      {
        # janneke's tcc-0.9.26 fork (the mes-tcc base); sha from live-bootstrap steps/tcc-0.9.26/sources.
        # Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= TCC_PKG).
        url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
        sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
        extract = true,
      } | Source,
      {
        # mes-0.27.1 source, re-extracted so tcc rebuilds mes-libc from lib/*.c. Same sha as
        # stage0-mes's Source. Extracts to /build/mes-0.27.1/ (= MES_PKG).
        url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
        sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
        extract = true,
      } | Source,
      # toolchain suppliers (chain-enforce predecessor edges):
      stage0-mes, # /usr/bin/{mes-m2,mescc.scm}, /usr/lib/x86_64-mes/**, /usr/include/**, /usr/share/{mes,nyacc}/**
      stage0-mescc-full, # /usr/bin/{kaem,catm,M1,hex2,blood-elf,match,M2-Mesoplanet,simple-patch}
      coreutils, # /usr/bin/{cp,chmod,mkdir,rm,sha256sum}
    ],
    # All tcc binaries are static ELF against mes-libc (CONFIG_TCC_STATIC=1): no .interp, no
    # DT_NEEDED, hence allow_missing_interpreter and no runtime_deps.
    cmds = [
      # The full kaem takes the script only via --file (no positional args).
      ["/usr/bin/kaem", "--strict", "--verbose", "--file", "tcc.kaem"],
    ],
    outputs = {
      # the deliverable: bakes the consumer /usr/lib/mes libdir (see tcc.kaem)
      tcc = { glob = "usr/bin/tcc", allow_missing_interpreter = true } | OutputBin,
      tcc_ver = { glob = "usr/bin/tcc-0.9.26", allow_missing_interpreter = true } | OutputBin,
      # intermediate compilers, kept for audit. They bake the staging libdir
      # /build/output/usr/lib/mes (fixed, so still reproducible). tcc-boot2 is removed after it
      # links the deliverable and is not exported.
      tcc_mes = { glob = "usr/bin/tcc-mes", allow_missing_interpreter = true } | OutputBin,
      tcc_boot0 = { glob = "usr/bin/tcc-boot0", allow_missing_interpreter = true } | OutputBin,
      tcc_boot1 = { glob = "usr/bin/tcc-boot1", allow_missing_interpreter = true } | OutputBin,
      # the tcc-rebuilt mes-libc stage0-tcc-0.9.27 links against. crti.o/crtn.o are empty on
      # amd64 (x86-only branch skipped); allow_data because empty .o files have no ELF magic.
      mes_libc = { glob = "usr/lib/mes/*.{a,o}", allow_data = true } | OutputLib,
      tcc_lib = { glob = "usr/lib/mes/tcc/libtcc1.a" } | OutputLib,
    },
    # source_provenance is omitted: attr_classes.ncl has no category for the janneke/lilypond fork.
    # The sha-pinned tcc Source above is the authoritative provenance.
    attrs =
      {
        upstream_version = "0.9.26",
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
      name = "stage0-tcc-0.9.26",
      build_deps = [],
    } | BuildSpec,
} target
