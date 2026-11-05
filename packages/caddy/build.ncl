let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.11.8" in
{
  name = "caddy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/caddyserver/caddy/v%{version}.tar.gz",
      sha256 = "50d4fe822eeb7fb779fa37fdc15d50c18472e1d6dffd941cd11d3d26cdc9072b",
      extract = true,
      strip_prefix = "caddy-%{version}",
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
    caddy = { glob = "usr/bin/caddy" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "caddy",
      source_provenance = {
        category = 'GithubRepo,
        owner = "caddyserver",
        repo = "caddy",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
