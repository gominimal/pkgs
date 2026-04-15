let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "2.12.7" in
{
  name = "nats-server",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/nats-server/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4a28aff2f4f98180a2bd17b5f175b96ca987204295268338e3468f6bc108e703",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "nats-io",
        repo = "nats-server",
      },
    } | Attrs,
} | BuildSpec
