let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "2.15.3" in
{
  name = "nats-server",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/nats-server/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "034a2a7535d67ae6f28962976a530dad1bd912dd2d9af05a3990f3b7e674008e",
      extract = true,
      strip_prefix = "nats-server-%{version}",
    } | Source,
    base,
    go,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  needs = {
    dns = {},
    internet = {},
  },

  outputs = {
    nats-server = { glob = "usr/bin/nats-server" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nats-io",
        repo = "nats-server",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/nats-server --version",
  },
} | BuildSpec
