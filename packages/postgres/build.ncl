let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let base = import "../base/build.ncl" in
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let icu = import "../icu/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# Minimal sessions set LANG=C.UTF-8, which the glibc locale-archive lacks;
# without it `initdb` aborts with "invalid locale settings".
let glibc-locale-c-utf8 = import "../glibc-locale-c-utf8/build.ncl" in

let version = "18.6" in

# server_test runs `check` (bash, with `start` and `q` defined) against a
# throwaway cluster, after the same passwd handling as initdb_c_utf8 below.
# `min check` reports which test failed but not its output, so keep one
# concern per test.
let server_test = fun check =>
  {
    class = 'Standalone,
    test_deps = [base],
    cmds = [
      [
        "/bin/bash",
        "-c",
        m%"
          set -eu
          if ! id -un >/dev/null 2>&1 && ! { echo "pgtest:x:$(id -u):$(id -g)::/tmp:/bin/sh" >> /etc/passwd; } 2>/dev/null; then echo "cannot run initdb: uid $(id -u) has no passwd entry and /etc/passwd is read-only" >&2; exit 2; fi
          d=$(mktemp -d)
          LANG=C.UTF-8 LC_ALL= /bin/initdb -A trust -D "$d/data" >"$d/initdb.log" 2>&1 || { cat "$d/initdb.log" >&2; exit 1; }
          start() { /bin/pg_ctl -D "$d/data" -o "-k $d -c listen_addresses=" -l "$d/server.log" -w start >/dev/null || { cat "$d/server.log" >&2; exit 1; }; }
          trap '/bin/pg_ctl -D "$d/data" -m immediate stop >/dev/null 2>&1 || true' EXIT
          q() { /bin/psql -h "$d" -d postgres -XAtq -v ON_ERROR_STOP=1 -c "$1"; }
        "%
        ++ "\n"
        ++ check,
      ],
    ],
  }
    | Test
in
{
  name = "postgres",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/postgresql-%{version}.tar.gz",
      sha256 = "983ee554ec53dbeb9b70797bef9fcf4e67e117e7e48ca1463cc80b3ff8e8ff3f",
    } | Source,
    base,
    make,
    perl,
    toolchain,
    flex,
    bison,
    m4,
    pkgconf,
  ],
  runtime_deps = [
    openssl,
    readline,
    icu,
    zstd,
    lz4,
    zlib,
    glibc-locale-c-utf8,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**", allow_data = true } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    share = { glob = "usr/share/postgresql/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "PostgreSQL",
      source_provenance = {
        category = 'GithubRepo,
        owner = "postgres",
        repo = "postgres",
      },
    } | Attrs,
  tests = {
    # A default `initdb` under the session locale must succeed and pick UTF8.
    # initdb looks up the running user, so it needs a passwd entry. `min check`
    # runs tests as a user that has one; a bare uid gets one appended where
    # /etc/passwd is writable. Anywhere else the test FAILS, naming the reason:
    # it never passes without running initdb.
    initdb_c_utf8 =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "if ! id -un >/dev/null 2>&1 && ! { echo \"pgtest:x:$(id -u):$(id -g)::/tmp:/bin/sh\" >> /etc/passwd; } 2>/dev/null; then echo \"cannot run initdb: uid $(id -u) has no passwd entry and /etc/passwd is read-only\" >&2; exit 2; fi; d=$(mktemp -d) && LANG=C.UTF-8 LC_ALL= /bin/initdb -D \"$d/data\" >\"$d/log\" 2>&1 || { cat \"$d/log\" >&2; exit 1; }; grep -q 'encoding has accordingly been set to \"UTF8\"' \"$d/log\""],
        ],
      } | Test,

    # Every extension contrib installed can be created, which loads its library.
    contrib_extensions_create =
      server_test m%"
        start
        for e in $(q "SELECT name FROM pg_available_extensions WHERE installed_version IS NULL"); do
          q "CREATE EXTENSION IF NOT EXISTS \"$e\" CASCADE"
        done
        test "$(q "SELECT count(*) FROM pg_available_extensions WHERE installed_version IS NULL")" = 0
        q "SELECT count(*) > 40 FROM pg_extension" | grep -qx t
      "%,

    pg_trgm =
      server_test m%"
        start
        q "CREATE EXTENSION pg_trgm"
        q "SELECT similarity('postgres', 'postgis') > 0.3" | grep -qx t
        q "CREATE TABLE t (s text); INSERT INTO t SELECT md5(g::text) FROM generate_series(1, 2000) g; CREATE INDEX t_s_trgm ON t USING gin (s gin_trgm_ops); ANALYZE t; SET enable_seqscan = off; EXPLAIN SELECT * FROM t WHERE s LIKE '%abc%'" | grep -q t_s_trgm
      "%,

    pgcrypto =
      server_test m%"
        start
        q "CREATE EXTENSION pgcrypto"
        q "SELECT encode(digest('abc', 'sha256'), 'hex')" | grep -qx ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        q "SELECT length(gen_random_bytes(16))" | grep -qx 16
        h=$(q "SELECT crypt('pw', gen_salt('bf'))")
        q "SELECT crypt('pw', '$h') = '$h'" | grep -qx t
        q "SELECT pgp_sym_decrypt(pgp_sym_encrypt('secret', 'k'), 'k')" | grep -qx secret
        q "SELECT convert_from(decrypt(encrypt('x', 'k', 'aes'), 'k', 'aes'), 'UTF8')" | grep -qx x
      "%,

    # encrypt()/decrypt() with bf, des or cast5 go through OpenSSL's legacy
    # provider, which the default openssl.cnf leaves off (as upstream documents).
    # This is the opt-in: a config that activates it, reaching the server.
    pgcrypto_legacy_provider =
      server_test m%"
        printf '%s\n' 'openssl_conf = openssl_init' '[openssl_init]' 'providers = provider_sect' '[provider_sect]' 'default = default_sect' 'legacy = legacy_sect' '[default_sect]' 'activate = 1' '[legacy_sect]' 'activate = 1' >"$d/openssl.cnf"
        export OPENSSL_CONF="$d/openssl.cnf"
        start
        q "CREATE EXTENSION pgcrypto"
        q "SELECT convert_from(decrypt(encrypt('x', 'k', 'bf'), 'k', 'bf'), 'UTF8')" | grep -qx x
      "%,

    # --with-lz4: LZ4 for TOAST and WAL compression.
    lz4_compression =
      server_test m%"
        start
        q "CREATE TABLE t (s text COMPRESSION lz4); INSERT INTO t SELECT repeat('lz4 ', 10000)"
        q "SELECT pg_column_compression(s) FROM t" | grep -qx lz4
        q "SELECT set_config('wal_compression', 'lz4', false)" | grep -qx lz4
      "%,
  },
} | BuildSpec
