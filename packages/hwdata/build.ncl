let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.403" in
{
  name = "hwdata",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vcrhonek/hwdata/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "77d0a69e5558d16d33bbb510a09093deaf11c882baf9ef6ec5f18a8ef96e2c13",
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

  attrs =
    {
      upstream_version = version,
      repology_project = "hwdata",
    } | Attrs,
} | BuildSpec
