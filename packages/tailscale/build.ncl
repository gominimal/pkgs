let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let iproute2 = import "../iproute2/build.ncl" in

let version = "1.102.2" in
{
  name = "tailscale",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tailscale/tailscale/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "66c447b5555aa89e0690dc21e0ec59421302ceaa982f3ccc0df686b16f5d5505",
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
