let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.13.2" in
{
  name = "ninja",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ninja-build/ninja/v%{version}.tar.gz",
      sha256 = "974d6b2f4eeefa25625d34da3cb36bdcebe7fbce40f4c16ac0835fd1c0cbae17",
      extract = true,
      strip_prefix = "ninja-%{version}",
    } | Source,
    base,
    python,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    ninja = { glob = "usr/bin/ninja" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "ninja",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ninja-build",
        repo = "ninja",
      },
    } | Attrs,
} | BuildSpec
