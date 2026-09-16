let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-musl-1.1.24: musl 1.1.24 compiled by tcc-0.9.27 from stage0-tcc-0.9.27 and installed
# as a static libc.a, crt*.o and headers. Derived from live-bootstrap steps/musl-1.1.24/pass1.sh.
# The build is configure + make, so the driver is build.sh under bash rather than kaem.
#
# CC=tcc compiles every .c and assembles every .s with tcc's integrated assembler (no binutils
# yet); AR="tcc -ar", RANLIB=true. musl is built -nostdinc against its own headers and only
# ever runs -c / -ar, so tcc's linker and the mes-libc at /usr/lib/mes are not exercised.
#
# live-bootstrap builds musl --host=i386; this builds --host=x86_64. Most of upstream's musl
# patches touch arch/i386 or src/*/i386 files that are never compiled for x86_64, or pair an
# arch-neutral hunk with an i386-only one (avoid_set_thread_area), so only the four
# arch-neutral live-bootstrap patches are carried, plus four amd64-specific patches for
# tcc-0.9.27 limits (see each patch header).
#
# stage0-mes supplies the mes headers at /usr/include/mes, tcc-0.9.27's baked sysinclude path,
# so configure's probe compiles resolve their includes. /usr is read-only at build time; make
# installs under DESTDIR=$OUTPUT_DIR.
let stage0-tcc-r3 = import "../stage0-tcc-0.9.27/build.ncl" in # /usr/bin/tcc, libtcc1.a, /usr/lib/mes
let stage0-mes = import "../stage0-mes/build.ncl" in # mes headers at /usr/include/mes for configure probes
let bash = import "../bash/build.ncl" in # build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # configure: config.mak generation
let grep = import "../grep/build.ncl" in # configure probes
let patch = import "../patch/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in # rm/mkdir/cp/chmod/install/cat/sort/tr/sha256sum
let tar = import "../tar/build.ncl" in # build.sh `tar -xf`
let gzip = import "../gzip/build.ncl" in # tar's .gz decompression
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # musl's configure uses awk once
let version = "1.1.24" in
let amd64_spec =
  {
    name = "stage0-musl-1.1.24",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # sha256sum -c pins for libc.a and crt*.o
      # arch-neutral patches, verbatim from live-bootstrap steps/musl-1.1.24
      { file = "makefile.patch" } | Local, # tcc -ar cannot create empty archives; touch the empty libs
      { file = "madvise_preserve_errno.patch" } | Local, # preserve errno across __madvise in malloc
      { file = "avoid_sys_clone.patch" } | Local, # posix_spawn: fork() instead of __clone
      { file = "disable_ctype_headers.patch" } | Local, # drop the iswalpha/... decls whose tables cannot be regenerated
      # amd64 patches for tcc-0.9.27 limits
      { file = "skip-pic-crt.patch" } | Local, # drop Scrt1.o/rcrt1.o: tcc crashes on the -fPIC %rip crt
      { file = "drop-dynamic-crt.patch" } | Local, # drop the _DYNAMIC lea from crt_arch.h: tcc crashes assembling it
      { file = "amd64-va-list.patch" } | Local, # define va_list for tcc, which has no __builtin_va_list
      { file = "amd64-syscall-arch.patch" } | Local, # rewrite __syscall4/5/6 without register-asm argument pinning
      {
        # sha256 from live-bootstrap steps/musl-1.1.24/sources. extract=false: build.sh runs tar.
        url = "gs://minimal-staging-archives/musl-%{version}.tar.gz",
        sha256 = "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3",
        extract = false,
      } | Source,
      stage0-tcc-r3, # /usr/bin/tcc (CC and `tcc -ar`), libtcc1.a, /usr/lib/mes
      stage0-mes, # /usr/include/** mes headers for configure probes
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
      # Only the versioned sysroot copy is captured, not the top-level usr/include and usr/lib.
      # In consumer sandboxes the merged /usr/{include,lib} is also written by glibc, and the
      # rootfs overlay is first-writer-wins, so consumers compile and link -nostdinc/-nostdlib
      # against this path, which no other package writes.
      sysroot_inc = { glob = "usr/lib/musl-bedrock-1.1.24/include/**" } | OutputData,
      # allow_data: libm/libpthread/librt/libcrypt/libutil/libxnet/libresolv/libdl.a are zero-byte
      # stubs (musl folds them into libc; makefile.patch touches them) with no file magic.
      sysroot_lib = { glob = "usr/lib/musl-bedrock-1.1.24/lib/**", allow_data = true } | OutputLib,
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
      name = "stage0-musl-1.1.24",
      build_deps = [],
    } | BuildSpec,
} target
