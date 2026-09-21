let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "15.2.0" in
{
  name = "ripgrep",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/BurntSushi/ripgrep/%{version}.tar.gz",
      sha256 = "7605249d3eb0d5f170e3414498e3344e26b1e7a147aec518b57090b80036a562",
      extract = true,
      strip_prefix = "ripgrep-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
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
} | BuildSpec
