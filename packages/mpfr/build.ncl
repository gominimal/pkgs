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
let m4 = import "../m4/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "4.2.2" in
{
  name = "mpfr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mpfr-%{version}.tar.xz",
      sha256 = "b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01"
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
    # other
    m4,
  ],
  runtime_deps = [
    glibc,
    gmp,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libmpfr.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libmpfr.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "mpfr (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/be4f04c67a274a5e868d715383db84f0f06963b271f7b62401b1cd6f9df28e8a/mpfr-glibc-4.2.2.tar.zst",
              sha256 = "be4f04c67a274a5e868d715383db84f0f06963b271f7b62401b1cd6f9df28e8a",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): stage0-mpfr-arm on our hex0-rooted toolchain, replacing the
              # dockcross/crosstool-NG artifact from bootstrap-aarch64-bins. Remaining deltas are
              # usr/share/doc/** the recipes never declare -- dockcross extras, not losses.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/5653e16b5777d76c64678236b097c104497d82326e9b7c42cb7e25e5625cf809/stage0-mpfr-arm-aarch64.tar.zst",
              sha256 = "5653e16b5777d76c64678236b097c104497d82326e9b7c42cb7e25e5625cf809",
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
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "mpfr",
      },
    } | Attrs,
} | BuildSpec
