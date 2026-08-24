let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.6.2" in
{
  name = "libtool",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libtool-%{version}.tar.xz",
      sha256 = "2ef1067c16c97db930fd740cc9bc3d3ba9a583804ae5ac42cc3e8719e49e191e",
      extract = true,
      strip_prefix = "libtool-%{version}",
    } | Source,
    base,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    bash,
    coreutils,
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libtoolize = { glob = "usr/bin/libtoolize" } | OutputBin,
    libtool = { glob = "usr/bin/libtool" } | OutputBin,
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
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "libtool",
      },
    } | Attrs,
} | BuildSpec
