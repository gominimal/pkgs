let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "3.54.1" in
{
  name = "sqlite",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-119586: upstream check-in d684ccc9ec4e41d8 re-targeted at the
    # amalgamated shell.c (provenance + adaptation in the patch header).
    { file = "CVE-2026-119586-recover-tail.patch" } | Local,
    {
      # ⚠ Nothing below derives from `version` above: the mirrored archive name
      # carries the zero-padded release number (major, then two digits per
      # component, then 00: 3.x.y -> 3xxyy00) and the
      # sha256 is its own copy. A bump must change all three together — this
      # line was left on 3500400 while version+sha256 moved to 3.53.3, so every
      # build failed HashMismatch until the 3.53.3 archive was mirrored.
      url = "gs://minimal-staging-archives/sqlite-autoconf-3540100.tar.gz",
      sha256 = "926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e"
    } | Source,
    base-bootstrap,
    make,
    patch,
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

  tests = {
    smoketest = standaloneTest "/usr/bin/sqlite3 --version",

    # CVE-2026-119586: .recover copied sqlite_schema.sql verbatim, so a
    # schema entry holding a valid CREATE followed by dot-command lines put
    # those commands into the recovery script, and they ran when the script
    # was piped into sqlite3. This is command injection, not memory
    # corruption: the test requires .recover to succeed (exit 0) and its
    # output to carry no planted dot-command, and requires that replaying it
    # neither runs the planted .shell nor prints the planted .print.
    recover-schema-tail =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -u
              fail() { echo "FAIL: $*" >&2; exit 1; }
              # No coreutils in the test sandbox: print a file with builtins.
              show() { while IFS= read -r l; do echo "$l"; done < "$1" >&2; }

              # 1. Upstream's own reproducer (test/misc01.sql testcase 400 in
              # check-in d684ccc9ec4e41d8), verbatim: sqlite_schema.sql is
              # "CREATE TABLE t1(a,b,c);" then a newline and ".print hello".
              /usr/bin/sqlite3 > upstream.out 2> upstream.err <<'END'
              .open --hexdb
              | size 8192 pagesize 4096 filename unk.db
              | page 1 offset 0
              |      0: 53 51 4c 69 74 65 20 66 6f 72 6d 61 74 20 33 00   SQLite format 3.
              |     16: 10 00 01 01 00 40 20 20 00 00 00 00 00 00 00 02   .....@  ........
              |     32: 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 04   ................
              |     48: 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00   ................
              |     96: 00 00 00 00 0d 00 00 00 01 0f ca 00 0f ca 00 00   ................
              |   4032: 00 00 00 00 00 00 00 00 00 00 34 01 06 17 11 11   ..........4.....
              |   4048: 01 55 74 61 62 6c 65 74 31 74 31 02 43 52 45 41   .Utablet1t1.CREA
              |   4064: 54 45 20 54 41 42 4c 45 20 74 31 28 61 2c 62 2c   TE TABLE t1(a,b,
              |   4080: 63 29 3b 0a 2e 70 72 69 6e 74 20 68 65 6c 6c 6f   c);..print hello
              | page 2 offset 4096
              |      0: 0d 00 00 00 00 10 00 00 00 00 00 00 00 00 00 00   ................
              | end unk.db
              .recover
              END
              rc=$?
              [ "$rc" -eq 0 ] || { show upstream.err; fail "upstream reproducer: sqlite3 exited $rc"; }
              /usr/bin/grep -qx 'CREATE TABLE t1(a,b,c);' upstream.out \
                || { show upstream.out; fail "upstream reproducer: recovered schema missing CREATE TABLE t1"; }
              if /usr/bin/grep -q 'print hello' upstream.out; then
                show upstream.out; fail "upstream reproducer: .recover emitted the planted '.print hello'"
              fi

              # 2. The attack itself: plant .shell and .print lines after a
              # valid CREATE, recover, and replay the script into a new db.
              /usr/bin/sqlite3 evil.db <<'END' || fail "could not build evil.db"
              CREATE TABLE t1(a);
              INSERT INTO t1 VALUES(42);
              PRAGMA writable_schema = ON;
              UPDATE sqlite_schema
                 SET sql = 'CREATE TABLE t1(a);' || char(10)
                        || '.shell echo ran > shell-ran' || char(10)
                        || '.print INJECTED-PRINT'
               WHERE name = 't1';
              END
              /usr/bin/sqlite3 evil.db .recover > recovered.sql 2> recover.err
              rc=$?
              [ "$rc" -eq 0 ] || { show recover.err; fail ".recover exited $rc"; }
              if /usr/bin/grep -nE '^[.](shell|system|print)' recovered.sql; then
                fail ".recover output carries a planted dot-command"
              fi
              /usr/bin/sqlite3 replay.db < recovered.sql > replay.out 2>&1
              if /usr/bin/grep -q INJECTED-PRINT replay.out; then
                show replay.out; fail "replaying .recover output ran the planted .print"
              fi
              [ ! -e shell-ran ] || fail "replaying .recover output ran the planted .shell"
              # The recovery itself must still work: table and row survive.
              got=$(/usr/bin/sqlite3 replay.db 'SELECT a FROM t1') || fail "replay.db unreadable"
              [ "$got" = 42 ] || fail "recovered t1 holds '$got', expected 42"
              echo "recover-schema-tail: ok"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
