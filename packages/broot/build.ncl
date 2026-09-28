let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.60.1" in
{
  name = "broot",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Canop/broot/v%{version}.tar.gz",
      sha256 = "23f6c5caed90400b4a7a277501c3c6fb46bacd4be5250da9ea357822e5a504ca",
      extract = true,
      strip_prefix = "broot-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    broot = { glob = "usr/bin/broot" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/broot" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/broot.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_broot" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Canop",
        repo = "broot",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
