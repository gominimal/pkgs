let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.5" in
{
  name = "libunistring",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libunistring-%{version}.tar.xz",
      sha256 = "fe89007a8a414ae4790b816b86859e877d3ab135db3c37f06541ff7e85ac344b",
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
