let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-gmp-mpfr-mpc: gmp-6.2.1, mpfr-4.1.0 and mpc-1.2.1 as static libraries, built by
# stage0-gcc-4.0.4 and linked against the musl-1.2.5 sysroot, for gcc's --with-gmp/--with-mpfr/
# --with-mpc. One combined package because the three are always consumed together and have a strict
# build order (gmp, mpfr, mpc). Output: /usr/lib/gcc-math/{lib,include}, a single-writer tree so
# consumers do not depend on the merged /usr. See build.sh.
let stage0-gcc-4-0-4 = import "../stage0-gcc-4.0.4/build.ncl" in # CC (via the gcc-cc wrapper)
let stage0-musl-1-2-5 = import "../stage0-musl-1.2.5/build.ncl" in # /usr/lib/musl-bedrock-1.2.5 sysroot (link libc)
let stage0-binutils-2-30 = import "../stage0-binutils-2.30/build.ncl" in # as/ld/ar/ranlib
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # gmp + mpfr are .tar.xz
let gzip = import "../gzip/build.ncl" in # mpc is .tar.gz
let m4 = import "../m4/build.ncl" in # gmp's configure wants m4 even with --disable-assembly
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let amd64_spec =
  {
    name = "stage0-gmp-mpfr-mpc",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/gmp-6.2.1.tar.xz",
        sha256 = "fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2",
        extract = false,
      } | Source,
      {
        url = "gs://minimal-staging-archives/mpfr-4.1.0.tar.xz",
        sha256 = "0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f",
        extract = false,
      } | Source,
      {
        url = "gs://minimal-staging-archives/mpc-1.2.1.tar.gz",
        sha256 = "17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459",
        extract = false,
      } | Source,
      stage0-gcc-4-0-4, # CC
      stage0-musl-1-2-5, # the sysroot the wrapper links against
      stage0-binutils-2-30, # as/ld/ar/ranlib on PATH
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      xz,
      gzip,
      m4,
      gawk-bootstrap,
    ],
    cmd = "./build.sh",
    outputs = {
      # the single-writer math tree gcc's --with-gmp/mpfr/mpc point at
      libs = { glob = "usr/lib/gcc-math/lib/*.a" } | OutputLib,
      includes = { glob = "usr/lib/gcc-math/include/**" } | OutputData,
    },
    attrs =
      {
        upstream_version = "6.2.1", # gmp's version; mpfr-4.1.0 + mpc-1.2.1 are pinned in the Sources above ('+' is not allowed in versions)
        repology_project = "gmp",
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-gmp-mpfr-mpc",
      build_deps = [],
    } | BuildSpec,
} target
