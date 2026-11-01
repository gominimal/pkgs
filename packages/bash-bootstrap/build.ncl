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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/f7ef704978ba7d1842589b475775876098b90cec8720ff051c2915230555d9dd/bash-bootstrap-x86_64.tar.zst",
              sha256 = "f7ef704978ba7d1842589b475775876098b90cec8720ff051c2915230555d9dd",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/435006aae82a32cbe8ad3262dd1dcd1fd506fbae40bc0b5cdb71b042c5f007cb/bash-bootstrap-aarch64.tar.zst",
              sha256 = "435006aae82a32cbe8ad3262dd1dcd1fd506fbae40bc0b5cdb71b042c5f007cb",
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
