let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.16.0" in
{
  name = "spire",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/spiffe/spire/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "5a3423c403f5bbe8bbd4595e56715e06610598854af364ad298ca6717473d9b3",
      extract = true,
      strip_prefix = "spire-%{version}",
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
    spire-server = { glob = "usr/bin/spire-server" } | OutputBin,
    spire-agent = { glob = "usr/bin/spire-agent" } | OutputBin,
    oidc-discovery-provider = { glob = "usr/bin/oidc-discovery-provider" } | OutputBin,
  },

  tests = {
    server_smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "v=$(/bin/spire-server --version 2>&1); echo \"$v\"; [[ $v == %{version} ]]"],
        ],
      } | Test,
    agent_smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "v=$(/bin/spire-agent --version 2>&1); echo \"$v\"; [[ $v == %{version} ]]"],
        ],
      } | Test,
    oidc_provider_smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "v=$(/bin/oidc-discovery-provider -version); echo \"$v\"; [[ $v == %{version} ]]"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "spiffe",
        repo = "spire",
      },
    } | Attrs,
} | BuildSpec
