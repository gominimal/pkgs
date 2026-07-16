let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.409" in
{
  name = "hwdata",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vcrhonek/hwdata/v%{version}.tar.gz",
      sha256 = "23006accc0f931dd5187d0307a57d0744e2b8feb85e73c37bc0f5229fb31eadd",
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
