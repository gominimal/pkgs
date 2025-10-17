let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.66.0" in
{
  name = "fzf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/junegunn/fzf/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "576659beee244b4ecccf45f1c576340143d8ce6d97fa053e6cbdd3f75c66b351",
      extract = true,
      strip_prefix = "fzf-%{version}",
    } | Source,
    base,
    ca-certificates, # TODO: Should probably be on Go?
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

    completions = { glob = "usr/share/bash-completion/*" } | OutputData,
  },
} | BuildSpec
