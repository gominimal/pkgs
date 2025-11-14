let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.66.1" in
{
  name = "fzf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/junegunn/fzf/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ae70923dba524d794451b806dbbb605684596c1b23e37cc5100daa04b984b706",
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

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
