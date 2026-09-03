let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.58.0" in
{
  name = "just",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/casey/just/archive/refs/tags/%{version}.tar.gz",
      sha256 = "c8a36e6e9397f2fdfcb0cc246fcdb790b52a784f3c8cabc0d8baeb031852a148",
      extract = true,
      strip_prefix = "just-%{version}",
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
    just = { glob = "usr/bin/just" } | OutputBin,

    bash_completion = { glob = "usr/share/bash-completion/completions/just" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/just.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_just" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "CC0-1.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "casey",
        repo = "just",
      },
    } | Attrs,
} | BuildSpec
