let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-binutils-2.30: binutils 2.30 (as, ld, ar, nm, objcopy, objdump, strip, ranlib, libbfd.a,
# libopcodes.a) built by tcc-musl2 and linked statically against the musl sysroot at
# /usr/lib/musl-bedrock. The tarball ships every generated file, so no autoreconf/bison/flex/perl
# are needed. See build.sh.
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in # CC: /usr/bin/tcc-musl2 + /usr/lib/tcc/libtcc1.a
let stage0-musl-r4b = import "../stage0-musl-1.1.24-cc2/build.ncl" in # link target: musl libc.a + crt + headers, and the /usr/lib/musl-bedrock sysroot
let bash = import "../bash/build.ncl" in # build.sh + configure shell
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # .tar.xz source
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
let diffutils = import "../diffutils/build.ncl" in # cmp for move-if-change / config.status
let version = "2.30" in
let amd64_spec =
  {
    name = "stage0-binutils-2.30",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local,
      # The three upstream patches belong to the regenerating (autoreconf) build path and are
      # carried for provenance only; build.sh does not apply them.
      { file = "libiberty-add-missing-config-directory-reference.patch" } | Local,
      { file = "new-gettext.patch" } | Local,
      { file = "opcodes-ensure-i386-init-dependencies-are-satisfied.patch" } | Local,
      {
        # upstream binutils 2.30 (.tar.xz). extract=false: build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
        sha256 = "6e46b8aeae2f727a36f0bd9505e405768a72218f1796f0d09757d45209871ae6",
        extract = false,
      } | Source,
      stage0-tcc-musl-s4, # /usr/bin/tcc-musl2 + /usr/lib/tcc/libtcc1.a
      stage0-musl-r4b, # /usr/lib/{libc.a,crt1.o,crti.o,crtn.o} + /usr/include/** (the link target)
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      xz,
      gawk-bootstrap,
      diffutils,
    ],
    build_args = {
      include version,
    },
    cmd = "./build.sh",
    outputs = {
      # the binutils tools + x86_64-linux-musl-<tool> symlinks. allow_executable: ELF programs kept
      # as OutputData because they carry the stage0 musl interpreter, which OutputBin's checker rejects.
      bin = { glob = "usr/bin/*", allow_executable = true } | OutputData,
      # libbfd.a / libopcodes.a / libiberty.a
      libs = { glob = "usr/lib/*.a" } | OutputLib,
      # bfd.h-class headers as an explicit list, never a wildcard over usr/include, so this package
      # can never contend for a libc header name in a consumer sandbox. Names absent in this release
      # match nothing.
      headers = { glob = "usr/include/{ansidecl,bfd,bfdlink,symcat,dis-asm,plugin-api,diagnostics,ctf,ctf-api,sframe,sframe-api}.h" } | OutputData,
    },
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-binutils-2.30",
      build_deps = [],
    } | BuildSpec,
} target
