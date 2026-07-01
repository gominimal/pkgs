let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "2.14.3" in
{
  name = "nats-server",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nats-io/nats-server/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "dba5286035ce9017b897ea24a783551dc28b07ad50c78da5471ead2bcfab3e86",
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
