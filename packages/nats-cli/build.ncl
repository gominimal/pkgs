let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.1" in
{
  name = "nats-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/natscli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "808a8905383949625e0a3f86821865eda29d381274021ff2d9ea7d7448c951fc",
      extract = true,
      strip_prefix = "natscli-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    nats = { glob = "usr/bin/nats" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nats-io",
        repo = "natscli",
      },
    } | Attrs,
} | BuildSpec
