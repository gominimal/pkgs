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

let version = "1.4.1" in
{
  name = "mpc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mpc-%{version}.tar.xz",
      sha256 = "91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931"
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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/8463137dd963e69f2a0d33bf5ab4766edc4dfaee579e6898b1337a6e6ba8c5b1/mpc-x86_64.tar.zst",
              sha256 = "8463137dd963e69f2a0d33bf5ab4766edc4dfaee579e6898b1337a6e6ba8c5b1",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/35cee42cd2b09b72f9c595df7b152a608ed395e15c4306608101a71ee9eb1d63/mpc-aarch64.tar.zst",
              sha256 = "35cee42cd2b09b72f9c595df7b152a608ed395e15c4306608101a71ee9eb1d63",
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
      license_spdx = "LGPL-3.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "mpc",
      },
    } | Attrs,
} | BuildSpec
