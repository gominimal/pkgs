let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.10" in
{
  name = "pkgconf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pkgconf-%{version}.tar.xz",
      sha256 = "9371b2f6372da574d4c6dc96fe9b1463037bcf6afcb6671c1555afde7b17e2de",
      extract = true,
      strip_prefix = "pkgconf-%{version}",
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    pkgconf = { glob = "usr/bin/pkgconf" } | OutputBin,
    bomtool = { glob = "usr/bin/bomtool" } | OutputBin,
    pkg-config = { glob = "usr/bin/pkg-config" } | OutputBin,
    libs = { glob = "usr/lib/libpkgconf.so*" } | OutputLib,

    includes = { glob = "usr/include/pkgconf/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pkgconf",
        repo = "pkgconf",
      },
    } | Attrs,
} | BuildSpec
