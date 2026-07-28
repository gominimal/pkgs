let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.11.4" in
{
  name = "caddy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/caddyserver/caddy/v%{version}.tar.gz",
      sha256 = "2c3d02078286a6282cdb4d1d8744077788d556659dac0b64d8ed5886a7e5aeb9",
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
