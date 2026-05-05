let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.21.0" in
{
  name = "libtasn1",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ftpmirror.gnu.org/libtasn1/libtasn1-%{version}.tar.gz",
      sha256 = "1d8a444a223cc5464240777346e125de51d8e6abf0b8bac742ac84609167dc87",
      extract = true,
      strip_prefix = "libtasn1-%{version}",
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
    bins = { glob = "usr/bin/asn1*" } | OutputBin,
    libs = { glob = "usr/lib/libtasn1.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GPL-3.0-only AND LGPL-2.1-only)",
      source_provenance = {
        category = 'GnuProject,
        name = "libtasn1",
      },
    } | Attrs,
} | BuildSpec
