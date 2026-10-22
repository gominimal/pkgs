let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.27.0" in
{
  name = "starship",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/starship/starship/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f1887ffa88a7ba437d2932501794047e28d03387996f7d1c364631c053cffc44",
      extract = true,
      strip_prefix = "starship-%{version}",
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
    starship = { glob = "usr/bin/starship" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/starship" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/starship.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_starship" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "starship",
        repo = "starship",
      },
    } | Attrs,
} | BuildSpec
