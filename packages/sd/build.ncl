let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.1.0" in
{
  name = "sd",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/chmln/sd/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "defdce484f8c92f265e1282490572575028967c2c55d356111d1e49a3ea9a88e",
      extract = true,
      strip_prefix = "sd-%{version}",
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
    sd = { glob = "usr/bin/sd" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/sd" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/sd.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_sd" } | OutputData,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["sd", "--version"]],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "chmln",
        repo = "sd",
      },
    } | Attrs,
} | BuildSpec
