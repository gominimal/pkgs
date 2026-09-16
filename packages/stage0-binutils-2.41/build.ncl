let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-binutils-2.41: binutils 2.41 (as, ld, ar, nm, objcopy, objdump, ranlib, readelf, strip,
# libbfd.a, libopcodes.a) built by stage0-gcc-4.7.4 and linked statically against the musl-1.2.5
# sysroot. gcc shells out to as/ld/ranlib, so stage0-binutils-2.30 is a build dep. binutils has no
# bignum middle-end, so gmp/mpfr/mpc are not needed. See build.sh.
let stage0-gcc-474 = import "../stage0-gcc-4.7.4/build.ncl" in # CC/CXX (gcc-4.7.4 / g++ via the gcc-cc/gcc-cxx wrappers)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # as/ld/ar/ranlib on PATH for the host gcc
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in # /usr/lib/musl-bedrock-1.2.5 sysroot (libc.a + crt + headers)
let bash = import "../bash/build.ncl" in # build.sh + configure shell
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # .tar.xz source
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let findutils = import "../findutils/build.ncl" in # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
let version = "2.41" in
let amd64_spec =
  {
    name = "stage0-binutils-2.41",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # byte-identity pins (unpinned placeholder)
      {
        # upstream binutils 2.41 (.tar.xz). extract=false: build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
        sha256 = "ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450",
        extract = false,
      } | Source,
      stage0-gcc-474, # CC + CXX
      stage0-binutils-r5, # /usr/bin/{as,ld,ar,ranlib} for the host gcc
      stage0-musl-r7, # musl-1.2.5 sysroot
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
      # as ld ar nm objcopy objdump ranlib readelf strip + addr2line c++filt size strings + the
      # x86_64-linux-gnu-<tool> symlinks. allow_executable: ELF programs kept as OutputData because
      # they carry the stage0 musl interpreter, which OutputBin's checker rejects.
      bin = { glob = "usr/bin/*", allow_executable = true } | OutputData,
      # libbfd.a / libopcodes.a / libctf.a / libsframe.a / libiberty.a
      libs = { glob = "usr/lib/*.a" } | OutputLib,
      # bfd.h-class headers (installed by --enable-install-libbfd) as an explicit list, never a
      # wildcard over usr/include, so this package can never contend for a libc header name in a
      # consumer sandbox. Names absent in this release match nothing.
      headers = { glob = "usr/include/{ansidecl,bfd,bfdlink,symcat,dis-asm,plugin-api,diagnostics,ctf,ctf-api,sframe,sframe-api}.h" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "binutils",
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-binutils-2.41",
      build_deps = [],
    } | BuildSpec,
} target
