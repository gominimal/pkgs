let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.67.0" in
{
  name = "fzf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/junegunn/fzf/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "da72936dd23045346769dbf233a7a1fa6b4cfe4f0e856b279821598ce8f692af",
      extract = true,
      strip_prefix = "fzf-%{version}",
    } | Source,
    base,
    go,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    fzf = { glob = "usr/bin/fzf" } | OutputBin,

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
