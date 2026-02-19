let { Attrs, BuildSpec, Local, OutputBin, Source, subsetOf, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.1" in
{
  name = "gperf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # http://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz
      url = "gs://minimal-staging-archives/gperf-%{version}.tar.gz",
      sha256 = "588546b945bba4b70b6a3a616e80b4ab466e3f33024a352fc2198112cdbb3ae2",
      extract = true,
      strip_prefix = "gperf-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    gperf = { glob = "usr/bin/gperf" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "gperf",
      },
    } | Attrs,
} | BuildSpec
