let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.15.2" in
{
  name = "spire",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/spiffe/spire/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "0ef800257cc709db57c92b5420e4e58396b8e63461bc36f26dcce349a147cd34",
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
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/spire-server --help || true"],
        ],
      } | Test,
    agent_smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/spire-agent --help || true"],
        ],
      } | Test,
    oidc_provider_smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/oidc-discovery-provider -version || true"],
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
