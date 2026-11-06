let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.11.9" in
{
  name = "caddy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/caddyserver/caddy/v%{version}.tar.gz",
      sha256 = "fefbe1f72b7a7e244f348c20eba377bb1e6964f51594229d2f38c49eaa2aa9a4",
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

  tests = {
    smoketest = standaloneTest "/usr/bin/caddy version",
  },
} | BuildSpec
