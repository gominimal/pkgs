let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, subsetOf, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let m4 = import "../m4/build.ncl" in
let perl = import "../perl/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.23.0" in
{
  name = "groff",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/groff-%{version}.tar.gz",
      sha256 = "6b9757f592b7518b4902eb6af7e54570bdccba37a871fddb2d30ae3863511c13"
    } | Source,
    base,
    toolchain,
    make,
    autoconf,
    automake,
    m4,
    perl,
  ],
  runtime_deps = [
    glibc,
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
      source_provenance = {
        category = 'GnuProject,
        name = "groff",
      },
    } | Attrs,
} | BuildSpec
