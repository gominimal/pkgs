let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.2" in
{
  name = "nats-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/natscli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6a735b879a19a7abaa4b45e512f23ddb7df6e8f1cd14b32091cd8568e4e94f63",
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

  tests = {
    smoketest = standaloneTest "/usr/bin/nats --version",
  },
} | BuildSpec
