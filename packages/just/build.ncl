let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.59.0" in
{
  name = "just",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/casey/just/archive/refs/tags/%{version}.tar.gz",
      sha256 = "20f876880851f1cc67fc7eb7589c7f7ccaa7612d827feac75797cf4a6ed729aa",
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
