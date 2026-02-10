let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.10.2" in
{
  name = "caddy",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/caddyserver/caddy/v%{version}.tar.gz",
      sha256 = "f63f46b7ae68ced0a5c2e31df1b6dfc7656117d162a1bc7fed4bd4afd14ddc8f",
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
      repology_project = "caddy",
    } | Attrs,
} | BuildSpec
