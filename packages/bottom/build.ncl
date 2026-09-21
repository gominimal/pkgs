let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.14.9" in
{
  name = "bottom",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ClementTsang/bottom/%{version}.tar.gz",
      sha256 = "1dbb940c763fb583b7e1c7dfa165b73ed9a0ba712e72cc97311c5b1c098d5b72",
      extract = true,
      strip_prefix = "bottom-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    btm = { glob = "usr/bin/btm" } | OutputLib,
    bash_completion = { glob = "usr/share/bash-completion/completions/btm" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/btm.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_btm" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "bottom",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ClementTsang",
        repo = "bottom",
      },
    } | Attrs,
} | BuildSpec
