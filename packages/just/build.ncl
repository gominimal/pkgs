let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.57.0" in
{
  name = "just",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/casey/just/archive/refs/tags/%{version}.tar.gz",
      sha256 = "905c556aad3c0a4b0376db98b706a9aa3485fcf50a30377d50737bf20f3792cb",
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
