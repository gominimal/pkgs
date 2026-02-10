let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.21.0" in
{
  name = "skopeo",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/containers/skopeo/v%{version}.tar.gz",
      sha256 = "f76eeddf697a3cc7a872e3077ab4d0fdbebe9f3c6171462e3e9feb84368b3fac",
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
  attrs.upstream_version = version,
} | BuildSpec
