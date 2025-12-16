let { Attrs, BuildSpec, Local, OutputBin, OutputData, Prebuilt, Source, .. } = import "minimal.ncl" in
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
let pcre2 = import "../pcre2/build.ncl" in

let version = "3.12" in
{
  name = "grep",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/grep-%{version}.tar.xz",
      sha256 = "2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9",
      extract = true,
      strip_prefix = "grep-%{version}",
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
    linux_headers,
    # other
  ],
  runtime_deps = [
    pcre2,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    grep_bin = { glob = "usr/bin/grep" } | OutputBin,
    egrep_bin = { glob = "usr/bin/egrep" } | OutputBin,
    fgrep_bin = { glob = "usr/bin/fgrep" } | OutputBin,

    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "grep",
  } | Attrs,

  replace_on_cycle =
    {
      name = "grep (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/grep/bc88864516b96d7d7b20e927f0129d57581a2a634f642522ae2f20ad2e15e391.tar.zst",
          sha256 = "0a031ab16d0f899eb5013eaffc1bc4b44c11531b0fa42226ad7b7511ccf2d493",
          extract = true,
        } | Source,
      ],
      runtime_deps = [
        pcre2,
      ],
      outputs = {
        grep_bin = { glob = "usr/bin/grep" } | OutputBin,
        egrep_bin = { glob = "usr/bin/egrep" } | OutputBin,
        fgrep_bin = { glob = "usr/bin/fgrep" } | OutputBin,
      },
    } | BuildSpec,
} | BuildSpec
