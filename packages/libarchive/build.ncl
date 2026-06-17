let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "3.8.7" in
{
  name = "libarchive",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libarchive-%{version}.tar.xz",
      sha256 = "d3a8ba457ae25c27c84fd2830a2efdcc5b1d40bf585d4eb0d35f47e99e5d4774",
    } | Source,
    base-bootstrap,
    make,
    toolchain,
    zlib,
    bzip2,
    xz,
  ],
  runtime_deps = [
    glibc,
    zlib,
    bzip2,
    xz,
  ],

  cmd = "./build.sh",

  outputs = {
    # The bsd* multi-format front-ends. bsdunzip (added upstream in 3.7.0) is the
    # maintained replacement for the EOL Info-ZIP `unzip` — see packages/unzip.
    bsdtar = { glob = "usr/bin/bsdtar" } | OutputBin,
    bsdcpio = { glob = "usr/bin/bsdcpio" } | OutputBin,
    bsdcat = { glob = "usr/bin/bsdcat" } | OutputBin,
    bsdunzip = { glob = "usr/bin/bsdunzip" } | OutputBin,

    libarchive = { glob = "usr/lib/libarchive.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
      repology_project = "libarchive",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libarchive",
        repo = "libarchive",
      },
    } | Attrs,
} | BuildSpec
