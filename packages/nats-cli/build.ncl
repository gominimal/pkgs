let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.0" in
{
  name = "nats-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/natscli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "832f2fcd53de5eceeb9d497ab603cbf32698646dfe156d23b70553e40eb1438b",
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
