let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.16.1" in
{
  name = "alsa-lib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # http://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2
      url = "gs://minimal-staging-archives/alsa-lib-%{version}.tar.bz2",
      sha256 = "f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e",
      extract = true,
      strip_prefix = "alsa-lib-%{version}",
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
    aserver = { glob = "usr/bin/aserver" } | OutputBin,

    libasound = { glob = "usr/lib/libasound*.so*" } | OutputLib,
    libatopology = { glob = "usr/lib/libatopology*.so*" } | OutputLib,

    alsa_data = { glob = "usr/share/alsa/**" } | OutputData,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-only",
      repology_project = "alsa-lib",
    } | Attrs,
} | BuildSpec
