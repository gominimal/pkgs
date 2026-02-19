let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.26" in
{
  name = "gdbm",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gdbm-%{version}.tar.gz",
      sha256 = "6a24504a14de4a744103dcb936be976df6fbe88ccff26065e54c1c47946f4a5e"
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
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libgdbm*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libgdbm.la" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "gdbm",
      },
    } | Attrs,
} | BuildSpec
