let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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

let version = "4.10.0" in
{
  name = "findutils",
  inputs = [
    {
      url = "gs://minimal-staging-archives/findutils-%{version}.tar.xz",
      sha256 = "1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
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
    find = { glob = "usr/bin/find" } | OutputBin,
    locate = { glob = "usr/bin/locate" } | OutputBin,
    updatedb = { glob = "usr/bin/updatedb" } | OutputBin,
    xargs = { glob = "usr/bin/xargs" } | OutputBin,

    libexec_frcode = { glob = "usr/libexec/frcode" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs.upstream_version = version,

  replace_on_cycle =
    {
      name = "findutils (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/findutils/6d2d376ab982c9fe5bc932457922e40984208f49b5d3419b00774f6f1f57df89.tar.zst",
          sha256 = "94a015e63faf0de0d4dd9d1d615c07a38e1baa2d0f5b7515b83abe0292ccac7e",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
