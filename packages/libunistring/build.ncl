let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.2" in
{
  name = "libunistring",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libunistring-%{version}.tar.gz",
      sha256 = "e82664b170064e62331962126b259d452d53b227bb4a93ab20040d846fec01d8",
      extract = true,
      strip_prefix = "libunistring-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      repology_project = "libunistring",
      source_provenance = {
        category = 'GnuProject,
        name = "libunistring",
      },
    } | Attrs,
} | BuildSpec
