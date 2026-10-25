let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.103.2" in
{
  name = "gh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/cli/cli/v%{version}.tar.gz",
      sha256 = "73a62f89937b2c058e0873a571f4963a28c7c78d3b60d0bf29e5658789eb8012",
      extract = true,
      strip_prefix = "cli-%{version}",
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
    gh = { glob = "usr/bin/gh" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/gh" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/gh.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_gh" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "gh",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cli",
        repo = "cli",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/gh --version",
  },
} | BuildSpec
