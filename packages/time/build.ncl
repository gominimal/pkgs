let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.10" in
{
  name = "time",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/time-%{version}.tar.xz",
      sha256 = "706bf7b8444ca9eb9037e9eda18e1d0eb7c2327ae7d8c2ce3a4823c5f80c7b11",
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
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "time",
      },
    } | Attrs,
} | BuildSpec
