let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-musl-1.1.24-cc2: musl 1.1.24 again, same source and patches as stage0-musl-1.1.24,
# but compiled by tcc-musl2 from stage0-tcc-0.9.27-musl-s3 (a musl-linked tcc-0.9.27) instead
# of the mes-linked tcc. tcc-musl2 has no mes-libc allocator, so its codegen is deterministic
# and this musl is the one downstream rungs link against. The dependency chain is
# stage0-musl-1.1.24 -> s1/s3 (tcc-musl2) -> this package, so there is no cycle.
#
# tcc-musl2 has the same tcc-0.9.27 codegen limits as the mes-linked tcc, so the same amd64
# patches and .s removals apply. musl compiles -nostdinc -Iinclude with its own stddef.h and
# stdarg.h, so tcc-musl2 needs no builtin header dir; it needs only itself and its libtcc1.a
# at /usr/lib/tcc/libtcc1.a, which the float gate in build.sh links against.
# stage0-musl-1.1.24's headers at /usr/include only satisfy tcc-musl2's baked sysinclude path
# for configure's probe compiles; the compile is -c/-ar only and never links against /usr/lib.
let stage0-tcc-musl-s3 = import "../stage0-tcc-0.9.27-musl-s3/build.ncl" in # tcc-musl2 + libtcc1.a
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in # musl headers at /usr/include for configure probes
let bash = import "../bash/build.ncl" in # build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # configure: config.mak generation
let grep = import "../grep/build.ncl" in # configure probes
let patch = import "../patch/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in # rm/mkdir/cp/chmod/install/cat/sort/tr/sha256sum
let tar = import "../tar/build.ncl" in # build.sh `tar -xf`
let gzip = import "../gzip/build.ncl" in # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # musl's configure uses awk once
let version = "1.1.24" in # source tarball version; the -cc2 suffix is only in `name`
let amd64_spec =
  {
    name = "stage0-musl-1.1.24-cc2",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # sha256sum -c pins; unpinned placeholder until recorded (see build.sh)
      # same patches as stage0-musl-1.1.24; see each patch header
      { file = "makefile.patch" } | Local, # tcc -ar cannot create empty archives; touch the empty libs
      { file = "madvise_preserve_errno.patch" } | Local, # preserve errno across __madvise in malloc
      { file = "avoid_sys_clone.patch" } | Local, # posix_spawn: fork() instead of __clone
      { file = "disable_ctype_headers.patch" } | Local, # drop the iswalpha/... decls whose tables cannot be regenerated
      { file = "skip-pic-crt.patch" } | Local, # drop Scrt1.o/rcrt1.o: tcc crashes on the -fPIC %rip crt
      { file = "drop-dynamic-crt.patch" } | Local, # drop the _DYNAMIC lea from crt_arch.h: tcc crashes assembling it
      { file = "amd64-va-list.patch" } | Local, # define va_list for tcc, which has no __builtin_va_list
      { file = "amd64-syscall-arch.patch" } | Local, # rewrite __syscall4/5/6 without register-asm argument pinning
      {
        # same tarball and sha as stage0-musl-1.1.24. extract=false: build.sh runs tar.
        url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
        sha256 = "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3",
        extract = false,
      } | Source,
      stage0-tcc-musl-s3, # /usr/bin/tcc-musl2 (CC and `tcc-musl2 -ar`), /usr/lib/tcc/libtcc1.a
      stage0-musl-r4, # musl headers at /usr/include for configure probes only
      bash,
      make,
      sed,
      grep,
      patch,
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
      # Only the sysroot copy is captured, not the top-level usr/include and usr/lib. In consumer
      # sandboxes the merged /usr/{include,lib} is also written by glibc and the rootfs overlay is
      # first-writer-wins, so consumers (the s4 gate, binutils-2.30, gcc-4.0.4) point at this path
      # with -nostdinc and explicit crt/libc. No other package writes here.
      sysroot_inc = { glob = "usr/lib/musl-bedrock/include/**" } | OutputData,
      # allow_data: the zero-byte stub archives from makefile.patch have no file magic.
      sysroot_lib = { glob = "usr/lib/musl-bedrock/lib/**", allow_data = true } | OutputLib,
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
      name = "stage0-musl-1.1.24-cc2",
      build_deps = [],
    } | BuildSpec,
} target
