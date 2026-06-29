let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.408" in
{
  name = "hwdata",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vcrhonek/hwdata/v%{version}.tar.gz",
      sha256 = "ac7c34efc5941d5cbf739a8f7f6c84b1c2edea493fd3fca10906ef64d7afd690",
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
