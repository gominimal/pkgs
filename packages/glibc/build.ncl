let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
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

  outputs = {
    etc = { glob = "etc/**/*" } | OutputLib,
    usr = { glob = "usr/**/*" } | OutputLib,
    var = { glob = "var/**/*" } | OutputLib,
  },
  attrs = {
    upstream_version = version,
    repology_project = "glibc",
  } | Attrs,

  replace_on_cycle =
    {
      name = "glibc (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/glibc/0b3158f86607d703484cdc2b989850085ee57cd9d774f00ff6bf5b83c9fb20db.tar.zst",
          sha256 = "0a8fe9137ed3e906bae9e1f922e80d6b198bd2d29d390f1283f7d32e0f921580",
          extract = true,
        } | Source,
      ],
      outputs = {
        etc = { glob = "etc/**/*" } | OutputLib,
        usr = { glob = "usr/**/*" } | OutputLib,
        var = { glob = "var/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
