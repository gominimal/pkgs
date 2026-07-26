let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.10.0" in
{
  name = "zoxide",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ajeetdsouza/zoxide/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4fcd4272b013a10b637dbcc299c58a9924b94470a9042677ca1a204cc2e9150e",
      extract = true,
      strip_prefix = "zoxide-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    zoxide = { glob = "usr/bin/zoxide" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/zoxide" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/zoxide.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_zoxide" } | OutputData,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["zoxide", "--version"]],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ajeetdsouza",
        repo = "zoxide",
      },
    } | Attrs,
} | BuildSpec
