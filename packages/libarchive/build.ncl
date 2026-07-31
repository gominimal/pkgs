let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let tar = import "../tar/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "3.8.1" in
{
  name = "libarchive",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Upstream: https://github.com/libarchive/libarchive/releases/download/v3.8.1/libarchive-3.8.1.tar.gz
      # STAGING: gcloud storage cp libarchive-3.8.1.tar.gz gs://minimal-staging-archives/
      url = "gs://minimal-staging-archives/libarchive-%{version}.tar.gz",
      sha256 = "bde832a5e3344dc723cfe9cc37f8e54bde04565bfe6f136bc1bd31ab352e9fab"
    } | Source,
    bash-bootstrap,
    make,
    sed,
    grep,
    gawk-bootstrap,
    tar,
    coreutils,
    toolchain,
    zlib,
    bzip2,
    zstd,
  ],
  runtime_deps = [
    glibc,
    zlib,
    bzip2,
    zstd,
  ],

  cmd = "./build.sh",
  outputs = {
    # Exists for diffoscope: python's libarchive-c dlopens libarchive.so.
    libarchive = { glob = "usr/lib/libarchive.so*" } | OutputLib,
    headers = { glob = "usr/include/archive*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libarchive.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libarchive",
        repo = "libarchive",
      },
    } | Attrs,
} | BuildSpec
