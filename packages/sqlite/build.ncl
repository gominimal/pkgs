let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "3.53.4" in
{
  name = "sqlite",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # ⚠ Nothing below derives from `version` above: the mirrored archive name
      # carries the zero-padded release number (3.53.3 -> 3530400) and the
      # sha256 is its own copy. A bump must change all three together — this
      # line was left on 3500400 while version+sha256 moved to 3.53.3, so every
      # build failed HashMismatch until the 3.53.3 archive was mirrored.
      url = "gs://minimal-staging-archives/sqlite-autoconf-3530400.tar.gz",
      sha256 = "0e9483900e92cd5de8fd48d16bf9200145a61f7fd5be542a5ac81d8a9516eb9c"
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
