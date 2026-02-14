let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# base
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
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
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in
let python = import "../python/build.ncl" in

let all_outputs = {
  bins = { glob = "usr/bin/**" } | OutputBin,
  sbins = { glob = "usr/sbin/**" } | OutputBin,
  etc = { glob = "etc/**/*" } | OutputData,

  libs = { glob = "usr/lib/*.{so*,a}" } | OutputLib,
  crts = { glob = "usr/lib/{crt,gcrt,grcrt,Mcrt,rcrt,Scrt}*.o" } | OutputLib,
  lib_audit = { glob = "usr/lib/audit/*.so*" } | OutputLib,
  lib_locale = { glob = "usr/lib/locale/**" } | OutputData,
  lib_gconv = { glob = "usr/lib/gconv/**", allow_data = true } | OutputLib,

  libexec_getconf = { glob = "usr/libexec/getconf/**" } | OutputLib,

  i18n = { glob = "usr/share/i18n/**" } | OutputData,
  locales = { glob = "usr/share/locale/**" } | OutputData,

  includes = { glob = "usr/include/**" } | OutputData,
}
in

let version = "2.42" in
{
  name = "glibc",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # Downloadable from: https://ftp.gnu.org/gnu/glibc/
      url = "gs://minimal-staging-archives/glibc-%{version}.tar.xz",
      sha256 = "d1775e32e4628e64ef930f435b67bb63af7599acb6be2b335b9f19f16509f17f"
    } | Source,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
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
    bison,
    m4,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = all_outputs,
  attrs =
    {
      upstream_version = version,
      repology_project = "glibc",
      source_provenance = {
        category = 'GnuProject,
        name = "glibc",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "glibc (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/glibc/arm64-linux-gnu/glibc_2.40_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "2c14aeca3c9f80c1b2f85b98c0aa0c1f4daf70e3081d84fac3ed9e71d8e2a8e4",
          extract = true,
        } | Source,
      ],
      outputs = all_outputs,
    } | BuildSpec,
} | BuildSpec
