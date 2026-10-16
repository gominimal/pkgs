let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.11.7" in
{
  name = "caddy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/caddyserver/caddy/v%{version}.tar.gz",
      sha256 = "86e39de5fa0bc433a9cd574a00e7751059903401f3389c61f8937fd0ad0180f5",
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
