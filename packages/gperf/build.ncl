let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.3" in
{
  name = "gperf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # http://ftp.gnu.org/gnu/gperf/gperf-3.3.tar.gz
      url = "gs://minimal-staging-archives/gperf-%{version}.tar.gz",
      sha256 = "fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8",
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
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "gperf",
      },
    } | Attrs,
} | BuildSpec
