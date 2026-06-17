let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.8" in
{
  name = "inetutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/inetutils-%{version}.tar.gz",
      sha256 = "57b3cf4f77555992881e5ba2a09a63b05aa2c56342a60ed4305b5f45938390b5"
    } | Source,
    base,
    make,
    sed,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "inetutils",
      },
    } | Attrs,
} | BuildSpec
