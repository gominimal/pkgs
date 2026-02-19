let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.9" in
{
  name = "time",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/time-%{version}.tar.gz",
      sha256 = "fbacf0c81e62429df3e33bda4cee38756604f18e01d977338e23306a3e3b521e",
      extract = true,
      strip_prefix = "time-%{version}",
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
    time = { glob = "usr/bin/time" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "time",
      },
    } | Attrs,
} | BuildSpec
