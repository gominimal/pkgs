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
      url = "gs://minimal-staging-archives/sqlite-autoconf-3500400.tar.gz",
      # Corrected 2026-08-03. The previous pin c917d7db… matched NOTHING: not upstream, not the
      # mirror object, not the tarball on disk. Verified three independent ways, all agreeing on
      # the value below — upstream https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz, the
      # mirror object fetched separately, and the archive's own contents (3,173,050 bytes, valid
      # gzip, containing sqlite-autoconf-3500400/sqlite3.c). A version bump where the sha did not
      # follow. This stale pin hard-failed mirror_hydrate::hydrate_sources for the WHOLE graph on
      # main — hex0 included, despite hex0 having zero deps and needing no sqlite.
      sha256 = "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18"
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
