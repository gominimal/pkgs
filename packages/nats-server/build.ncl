let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "2.15.1" in
{
  name = "nats-server",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/nats-server/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "41b25fcb78a174f3afce4ec1eca0c1035439abf580f0a0569dbb03bd0d955e08",
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
} | BuildSpec
