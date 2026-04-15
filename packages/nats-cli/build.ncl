let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.3.2" in
{
  name = "nats-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/natscli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6b9412aff41a0340c58ed349742890955667c874fe1295b3b39b2fef376b915f",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "nats-io",
        repo = "natscli",
      },
    } | Attrs,
} | BuildSpec
