let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.4" in
{
  name = "pkgconf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pkgconf-%{version}.tar.xz",
      sha256 = "91ce346b47f46b87d680c6928e6c43240b9cdc7a31afbea19f2298de4dbe266d",
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
      license_spdx = "pkgconf",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pkgconf",
        repo = "pkgconf",
      },
    } | Attrs,
} | BuildSpec
