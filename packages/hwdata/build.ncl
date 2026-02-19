let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.404" in
{
  name = "hwdata",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vcrhonek/hwdata/v%{version}.tar.gz",
      sha256 = "5c14fc99bf193faad1ccc267ccfff14ee4e4550a582b17a76aec72178539f837",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "vcrhonek",
        repo = "hwdata",
      },
    } | Attrs,
} | BuildSpec
