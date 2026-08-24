let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.410" in
{
  name = "hwdata",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vcrhonek/hwdata/v%{version}.tar.gz",
      sha256 = "2864b061b179b8ad8cb6a7339ca07678240a183d9cedce8677a4950acaf798e0",
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
      license_spdx = "GPL-2.0-only",
      repology_project = "hwdata",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vcrhonek",
        repo = "hwdata",
      },
    } | Attrs,
} | BuildSpec
