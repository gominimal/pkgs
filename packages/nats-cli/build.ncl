let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.4.0" in
{
  name = "nats-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/natscli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6dc9056aa439f90de2a705983005363ae05f1f9985b81881cbfffa867a344ef6",
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
