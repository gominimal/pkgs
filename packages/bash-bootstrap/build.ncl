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
    source_provenance = {
      category = 'GnuProject,
      name = "bash",
    },
    license_spdx = "GPL-3.0-only",
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
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/d4c7f29a230757b87cd3372437026d812aa8baf7b2d7c468e073656710578abd/stage0-bash-bedrock-aarch64.tar.zst",
              sha256 = "d4c7f29a230757b87cd3372437026d812aa8baf7b2d7c468e073656710578abd",
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
