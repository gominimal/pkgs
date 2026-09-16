let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-musl-1.2.5: stock musl 1.2.5 (no patches) compiled by gcc-4.0.4 from stage0-gcc-4.0.4
# and assembled/linked by binutils-2.30. gcc handles everything the tcc-era musl patches worked
# around (PIC crt, __builtin_va_list, register-asm syscall args, SSE .s, @PLT, empty archives).
#
# build.sh wraps gcc so its baked include/lib search never reaches the merged /usr (also written
# by glibc in the sandbox): compiles get `-nostdinc -isystem <gcc's own headers>` only, since musl
# supplies its own headers with -Iinclude; links get -isystem/-B/-L on stage0-musl-1.1.24-cc2's
# /usr/lib/musl-bedrock so configure's probe links resolve musl crt and libc. musl's own libc.a is
# built from its own objects and never links against the 1.1.24 libc.
#
# Outputs include a versioned sysroot copy at /usr/lib/musl-bedrock-1.2.5, distinct from the
# 1.1.24 one, for the gcc wrappers of later rungs (gmp/mpfr/mpc, gcc-4.7.4).
# Not included: linux kernel headers. musl builds without them; add a second Source when a
# downstream rung needs <linux/*.h>.
let stage0-gcc = import "../stage0-gcc-4.0.4/build.ncl" in # gcc/cc1/cpp + libgcc.a
let stage0-musl-r4b = import "../stage0-musl-1.1.24-cc2/build.ncl" in # /usr/lib/musl-bedrock, link libc for configure probes
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in # build.sh and configure interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # configure: config.mak generation
let grep = import "../grep/build.ncl" in # configure probes
let coreutils = import "../coreutils/build.ncl" in # rm/mkdir/cp/ln/install/sha256sum
let tar = import "../tar/build.ncl" in # build.sh `tar -xf`
let gzip = import "../gzip/build.ncl" in # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # musl configure's awk
let version = "1.2.5" in
let amd64_spec =
  {
    name = "stage0-musl-1.2.5",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # sha256sum -c pins; unpinned placeholder until recorded (see build.sh)
      {
        # extract=false: build.sh runs tar.
        url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
        sha256 = "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4",
        extract = false,
      } | Source,
      stage0-gcc, # CC via the gcc-cc wrapper in build.sh
      stage0-musl-r4b, # explicit: the /usr/lib/musl-bedrock sysroot the wrapper links against
      stage0-binutils-r5, # explicit: as/ld/ar/ranlib on PATH
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      gzip,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    cmd = "./build.sh",
    outputs = {
      libc = { glob = "usr/lib/libc.a" } | OutputLib,
      crt = { glob = "usr/lib/*.o" } | OutputLib,
      libs = { glob = "usr/lib/*.a" } | OutputLib,
      includes = { glob = "usr/include/**" } | OutputData,
      # versioned sysroot copy; the single-level usr/lib/*.{a,o} globs above do not match this
      # nested path, so nothing is captured twice
      sysroot_inc = { glob = "usr/lib/musl-bedrock-1.2.5/include/**" } | OutputData,
      sysroot_lib = { glob = "usr/lib/musl-bedrock-1.2.5/lib/**" } | OutputLib,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "musl",
      } | Attrs,
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-musl-1.2.5",
      build_deps = [],
    } | BuildSpec,
} target
