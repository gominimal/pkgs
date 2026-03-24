let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let version = "5.3" in
{
  name = "bash-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bash-%{version}.tar.gz",
      sha256 = "0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba",
      extract = true,
    } | Source,
    bash-bootstrap,
    coreutils,
    gawk-bootstrap,
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
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bash = { glob = "usr/bin/bash" } | OutputBin,
    sh = { glob = "usr/bin/sh" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
  },

  replace_on_cycle =
    {
      name = "bash-bootstrap (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/bash-bootstrap/amd64-linux-gnu/bash-bootstrap_5.3_amd64-linux-gnu_prebuilt_363e67d.tar.zst",
              sha256 = "cd6e5b8af486a82aa5e9b6cffda572105860afe81407e5d7b509bff7f5ece578",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/bash-bootstrap/arm64-linux-gnu/bash-bootstrap_5.3_arm64-linux-gnu_prebuilt_363e67d.tar.zst",
              sha256 = "6fbed96eb0e33940ee8a749db0c3d0b6bbd74152480e556e01208eaaaf01adc8",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        glibc,
      ],
      outputs = {},
    } | BuildSpec,
} | BuildSpec
