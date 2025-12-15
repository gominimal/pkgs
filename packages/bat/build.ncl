let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let oniguruma = import "../oniguruma/build.ncl" in

let version = "0.26.1" in
{
  name = "bat",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/sharkdp/bat/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4474de87e084953eefc1120cf905a79f72bbbf85091e30cf37c9214eafcaa9c9",
      extract = true,
      strip_prefix = "bat-%{version}",
    } | Source,
    base,
    rust,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    zlib,
    gcc, # TODO, weird
    oniguruma,
  ],

  cmd = "./build.sh",

  outputs = {
    bat = { glob = "usr/bin/bat" } | OutputBin,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
