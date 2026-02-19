let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.72" in
{
  name = "autoconf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/autoconf-%{version}.tar.xz",
      sha256 = "ba885c1319578d6c94d46e9b0dceb4014caafe2490e437a0dbca3f270a223f5a",
      extract = true,
      strip_prefix = "autoconf-%{version}",
    } | Source,
    base,
    m4,
    make,
    perl,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    autoconf_data = { glob = "usr/share/autoconf/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "autoconf",
      },
    } | Attrs,
} | BuildSpec
