let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.55.1" in
{
  name = "just",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/casey/just/archive/refs/tags/%{version}.tar.gz",
      sha256 = "40a2d3725480523ffebb762669cafe2b0135a00383946eec3d47adf5e9be6345",
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

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
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
