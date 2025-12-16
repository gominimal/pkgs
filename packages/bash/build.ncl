let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Prebuilt, Source, .. } = import "minimal.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let readline = import "../readline/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let version = "5.3" in
{
  name = "bash",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bash-%{version}.tar.gz",
      sha256 = "0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba",
      extract = true,
    } | Source,
    bash,
    coreutils,
    gawk,
    grep,
    make,
    sed,
    # toolchain
    binutils,
    gcc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    ncurses,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bash = { glob = "usr/bin/bash" } | OutputBin,
    sh = { glob = "usr/bin/sh" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "bash",
  } | Attrs,

  replace_on_cycle =
    {
      name = "bash (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/bash/0932485779c77fb91805ea37baf5a97b6c64f1f45d2794b10f61eb0d805928d0.tar.zst",
          sha256 = "bdb617c43eb4ba70f72a3a9750266cd57cb1cbc77db19e50366f50cacc5afcd7",
          extract = true,
        } | Source,
      ],
      runtime_deps = [
        glibc,
        ncurses,
        readline,
      ],
      outputs = {},
    } | BuildSpec,
} | BuildSpec
