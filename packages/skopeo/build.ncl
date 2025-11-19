let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.20.0" in
{
  name = "skopeo",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/containers/skopeo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "0c19fe51b2cd8d1bd5e38c03b97421e318fc08153bdf5ef2f816a29889eacdef",
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
