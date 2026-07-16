let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let iproute2 = import "../iproute2/build.ncl" in

let version = "1.98.8" in
{
  name = "tailscale",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tailscale/tailscale/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4dfd5e53b6ea0a7827bbe3e8d922b7b16fb91034effcdce243e61eacd183e41d",
      extract = true,
      strip_prefix = "tailscale-%{version}",
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
    iproute2,
    # TODO: add iptables package when available (runtime dep for tailscaled NAT/firewall rules)
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    tailscale = { glob = "usr/bin/tailscale" } | OutputBin,
    tailscaled = { glob = "usr/sbin/tailscaled" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      repology_project = "tailscale",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tailscale",
        repo = "tailscale",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["/bin/tailscale", "version"]],
      } | Test,
  },
} | BuildSpec
