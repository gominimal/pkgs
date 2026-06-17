let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let oniguruma = import "../oniguruma/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "0.18.2" in
{
  name = "delta",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dandavison/delta/%{version}.tar.gz",
      sha256 = "64717c3b3335b44a252b8e99713e080cbf7944308b96252bc175317b10004f02",
      extract = true,
      strip_prefix = "delta-%{version}",
    } | Source,
    base,
    rust,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    oniguruma,
    subsetOf diffutils ["diff", "diff3"],
    subsetOf gcc ["libgcc"],
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    delta = { glob = "usr/bin/delta" } | OutputBin,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dandavison",
        repo = "delta",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
