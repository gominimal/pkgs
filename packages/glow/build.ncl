let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "2.1.1" in
{
  name = "glow",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/charmbracelet/glow/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f13e1d6be1ab4baf725a7fedc4cd240fc7e5c7276af2d92f199e590e1ef33967",
      extract = true,
      strip_prefix = "glow-%{version}",
    } | Source,
    base,
    ca-certificates, # TODO: Should probably be on Go?
    go,
    toolchain,
  ],

  cmd = "./build.sh",

  outputs = {
    glow = { glob = "usr/bin/glow" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
