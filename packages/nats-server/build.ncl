let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "2.14.7" in
{
  name = "nats-server",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/nats-server/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "094114987c7f7d45347a77e1731a394d002115669b802b5475ef515d342358cc",
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
