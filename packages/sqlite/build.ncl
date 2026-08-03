let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "3.53.3" in
{
  name = "sqlite",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Fixed 2026-08-03: the URL was stale, NOT the sha. build.sh:5 does
      # `cd sqlite-autoconf-3530300`, i.e. 3.53.3, and the pin c917d7db… is exactly upstream's
      # sha256 for sqlite-autoconf-3530300.tar.gz (verified by fetching it). Only the URL still
      # pointed at 3.50.4, so hydration fetched the wrong tarball and the sha check correctly
      # refused it. Both fields now agree at 3.53.3, which is what build.sh unpacks.
      url = "gs://minimal-staging-archives/sqlite-autoconf-3530300.tar.gz",
      sha256 = "c917d7db16648ec95f714974ace5e5dcf46b7dc70e26600a0a102a3141125db0"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    sqlite3 = { glob = "usr/bin/sqlite3" } | OutputBin,
    libs = { glob = "usr/lib/libsqlite3.so*" } | OutputLib,

    includes = { glob = "usr/include/sqlite3*.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "blessing",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sqlite",
        repo = "sqlite",
      },
    } | Attrs,
} | BuildSpec
