let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.5.3" in
{
  name = "bzip3",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/iczelia/bzip3/releases/download/%{version}/bzip3-%{version}.tar.xz",
      sha256 = "58a53d002eb80c6f74c292ddf37d4f53604f6e2126cb3ae2bff738971302aa85",
      extract = true,
      strip_prefix = "bzip3-%{version}",
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
    bzip3 = { glob = "usr/bin/bzip3" } | OutputBin,
    bunzip3 = { glob = "usr/bin/bunzip3" } | OutputBin,
    bz3cat = { glob = "usr/bin/bz3cat" } | OutputBin,
    bz3grep = { glob = "usr/bin/bz3grep" } | OutputBin,
    bz3less = { glob = "usr/bin/bz3less" } | OutputBin,
    bz3more = { glob = "usr/bin/bz3more" } | OutputBin,
    bz3most = { glob = "usr/bin/bz3most" } | OutputBin,

    libs = { glob = "usr/lib/libbzip3{.a,.so*}" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libbzip3.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    headers = { glob = "usr/include/libbz3.h" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "bzip3",
    } | Attrs,
} | BuildSpec
