let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.2.1" in
{
  name = "age",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/FiloSottile/age/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "93bd89a16c74949ee7c69ef580d8e4cf5ce03e7d9c461b68cf1ace3e4017eef5",
      extract = true,
      strip_prefix = "age-%{version}",
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

  outputs = {
    age = { glob = "usr/bin/age" } | OutputBin,
  },

  attrs.upstream_version = version,
} | BuildSpec
