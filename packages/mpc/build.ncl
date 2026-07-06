let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let gmp = import "../gmp/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in

let version = "1.4.0" in
{
  name = "mpc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mpc-%{version}.tar.xz",
      sha256 = "3210b3a546b1cb00c296ca360891d7740ee6ff06deb02a27a35b20cd3c0bb1a5"
    } | Source,
    # base
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    gmp,
    mpfr,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libmpc.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libmpc.la" } | OutputData,
    includes = { glob = "usr/include/mpc.h" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },
  replace_on_cycle =
    {
      name = "mpc (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimalmertic-release-channel-stable/mpc-glibc-1.4.0/mpc-glibc-1.4.0.tar.zst",
              sha256 = "a385e3fa185012d00bd68131f7fa8789c5207fefe89411b9f7ea4c3869469c53",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/mpc/arm64-linux-gnu/mpc_1.3.1_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "8bbeb25848856021b15100d7bf1b2f08d7635d4cc6189c8441a465637b3493bd",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "mpc",
      },
    } | Attrs,
} | BuildSpec
