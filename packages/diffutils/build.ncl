let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Prebuilt, Source, .. } = import "minimal.ncl" in
let bash = import "../gcc/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let gcc = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "3.12" in
{
  name = "diffutils",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffutils-%{version}.tar.xz",
      sha256 = "7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd",
      extract = true,
    } | Source,
    bash,
    binutils,
    coreutils,
    diffutils,
    gawk,
    gcc,
    glibc,
    grep,
    make,
    linux_headers,
    sed,
    tar,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cmp = { glob = "usr/bin/cmp" } | OutputBin,
    diff = { glob = "usr/bin/diff" } | OutputBin,
    diff3 = { glob = "usr/bin/diff3" } | OutputBin,
    sdiff = { glob = "usr/bin/sdiff" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs.upstream_version = version,

  replace_on_cycle =
    {
      name = "diffutils (prebuilt)",
      inputs = [
        { package = "diffutils" } | Prebuilt,
      ],
      cmd = "",
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
