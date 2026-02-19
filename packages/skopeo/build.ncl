let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.22.0" in
{
  name = "skopeo",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/containers/skopeo/v%{version}.tar.gz",
      sha256 = "dc9aa749973b10d3c2672d2839e61bac75cf32d5e5106463420b83653c9df3ff",
      extract = true,
      strip_prefix = "skopeo-%{version}",
    } | Source,
    base,
    go,
    make,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    skopeo = { glob = "usr/bin/skopeo" } | OutputBin,

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "containers",
        repo = "skopeo",
      },
    } | Attrs,
} | BuildSpec
