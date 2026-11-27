let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "16.0.0" in
{
  name = "ripgrep",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/BurntSushi/ripgrep/%{version}.tar.gz",
      sha256 = "17e7a1a0db80ed9618a0963c7ae4aecb8fce25c70cf7ebed514daf2b38a0d153",
      extract = true,
      strip_prefix = "ripgrep-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    rg = { glob = "usr/bin/rg" } | OutputBin,

    bash_completion = { glob = "usr/share/bash-completion/completions/rg" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/rg.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_rg" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Unlicense",
      source_provenance = {
        category = 'GithubRepo,
        owner = "BurntSushi",
        repo = "ripgrep",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/rg --version",
  },
} | BuildSpec
