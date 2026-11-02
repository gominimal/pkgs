let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let m4 = import "../m4/build.ncl" in

let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let perl = import "../perl/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.24.2" in
{
  name = "groff",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/groff-%{version}.tar.gz",
      sha256 = "f9c1efd5bebbe37fc6e1063db7473ce8df1e3e0be4ff0f43ce04fce57e9c5dd9"
    } | Source,
    base,
    toolchain,
    make,
    autoconf,
    automake,
    m4,
  ],
  runtime_deps = [
    bash,
    coreutils,
    glibc,
    perl,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    data = { glob = "usr/share/groff/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "groff",
      },
    } | Attrs,
} | BuildSpec
