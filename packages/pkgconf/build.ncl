let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.3" in
{
  name = "pkgconf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pkgconf-%{version}.tar.xz",
      sha256 = "aa033abb2b777ba4e66635495a931e53c49d86e4e4e38af68c0f76d666cbd8cf",
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
