let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.4" in
{
  name = "libtool",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libtool-%{version}.tar.xz",
      sha256 = "f81f5860666b0bc7d84baddefa60d1cb9fa6fceb2398cc3baca6afaa60266675",
      extract = true,
      strip_prefix = "libtool-%{version}",
    } | Source,
    base,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libltdl.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,

    share = { glob = "usr/share/libtool/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "libtool",
      },
    } | Attrs,
} | BuildSpec
