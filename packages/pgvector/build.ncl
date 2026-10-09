let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let postgres = import "../postgres/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let glibc-locale-c-utf8 = import "../glibc-locale-c-utf8/build.ncl" in

# pgvector: vector similarity search for Postgres (`CREATE EXTENSION
# vector`), used by Rails apps for embeddings/AI features (the neighbor gem,
# Chatwoot, ...). Installs into the postgres package's extension dirs.
let version = "0.8.7" in
{
  name = "pgvector",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pgvector/pgvector/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cac0b10c360f05b2d521200105ba3697e773d4cd3731f5a915a7e37ebe0bea85",
      extract = true,
      strip_prefix = "pgvector-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    postgres,
  ],
  runtime_deps = [
    glibc,
    postgres,
  ],
  cmd = "./build.sh",
  outputs = {
    lib = { glob = "usr/lib/postgresql/vector.so" } | OutputLib,
    extension = { glob = "usr/share/postgresql/extension/vector*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "PostgreSQL",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pgvector",
        repo = "pgvector",
      },
    } | Attrs,
  tests = {
    # A real server: create the extension and run a nearest-neighbour query.
    knn_query =
      {
        class = 'Standalone,
        test_deps = [base, glibc-locale-c-utf8],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              id -un >/dev/null 2>&1 || echo "pgtest:x:$(id -u):$(id -g)::/tmp:/bin/sh" >> /etc/passwd
              d=$(mktemp -d)
              LANG=C.UTF-8 initdb -D "$d/data" --auth=trust >/dev/null
              pg_ctl -D "$d/data" -o "-c listen_addresses= -k $d" -l "$d/log" -w start >/dev/null
              trap 'pg_ctl -D "$d/data" -m fast stop >/dev/null' EXIT
              out=$(psql -h "$d" -d postgres -tAc "CREATE EXTENSION vector; CREATE TABLE t (v vector(3)); INSERT INTO t VALUES ('[1,0,0]'), ('[0,1,0]'); SELECT v FROM t ORDER BY v <-> '[0.9,0.1,0]' LIMIT 1;" | tail -1)
              test "$out" = "[1,0,0]" || { echo "got: $out" >&2; exit 1; }
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
