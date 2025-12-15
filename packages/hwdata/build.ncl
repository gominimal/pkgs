let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.402" in
{
  name = "hwdata",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vcrhonek/hwdata/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e390fe2f5f5ef7ed9ccbe62eb7cd40d4ee2b57389e7869c0dc96433c81812e7a",
      extract = true,
      strip_prefix = "hwdata-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    hwdata = { glob = "usr/share/hwdata/*" } | OutputData,

    pkgconfigs = { glob = "usr/share/pkgconfig/*" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "hwdata",
  } | Attrs,
} | BuildSpec
