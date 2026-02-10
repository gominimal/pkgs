let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "15.1.0" in
{
  name = "ripgrep",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/BurntSushi/ripgrep/%{version}.tar.gz",
      sha256 = "046fa01a216793b8bd2750f9d68d4ad43986eb9c0d6122600f993906012972e8",
      extract = true,
      strip_prefix = "ripgrep-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    rg = { glob = "usr/bin/rg" } | OutputBin,

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
