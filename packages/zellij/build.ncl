let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.44.3" in
{
  name = "zellij",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zellij-org/zellij/v%{version}.tar.gz",
      sha256 = "33ae61fc802b59462fed49b424893596d3aa819646bdce53d5602f714c1264fe",
      extract = true,
      strip_prefix = "zellij-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    openssl,
  ],

  runtime_deps = [
    glibc,
    gcc,
    openssl,
  ],

  cmd = "./build.sh",

  outputs = {
    zellij = { glob = "usr/bin/zellij" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "zellij-org",
        repo = "zellij",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
