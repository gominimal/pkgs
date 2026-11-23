let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in

let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "9.2.0" in

# Start a throwaway server on loopback (no persistence, so nothing is written on
# shutdown) and wait until it answers PING. 127.0.0.1, not localhost: the test sandbox
# has no /etc/hosts.
let start-server = m%"
  port=6391
  valkey-server --bind 127.0.0.1 --port "$port" --save '' --appendonly no --daemonize no > server.log 2>&1 &
  srv=$!
  trap 'kill "$srv" 2>/dev/null || true; cat server.log' EXIT
  for _ in $(seq 1 50); do
    [ "$(valkey-cli -h 127.0.0.1 -p "$port" PING 2>/dev/null)" = PONG ] && break
    sleep 0.1
  done
  [ "$(valkey-cli -h 127.0.0.1 -p "$port" PING)" = PONG ]
"%
in
{
  name = "valkey",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/valkey-io/valkey/archive/refs/tags/%{version}.tar.gz",
      sha256 = "a02cb44db1269b699629e419d4949e6e51e984b1f0e9a984e8ee1e1b3b7cc36f",
      extract = true,
      strip_prefix = "valkey-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  build_args = { include version },

  # No redis-* compat symlinks: build.sh installs with USE_REDIS_SYMLINKS=no and fails
  # if any redis-named file is produced, so this package and packages/redis share no
  # path. valkey-check-aof, valkey-check-rdb and valkey-sentinel are upstream's
  # symlinks to valkey-server, which picks its mode from argv[0].
  outputs = {
    valkey-server = { glob = "usr/bin/valkey-server" } | OutputBin,
    valkey-cli = { glob = "usr/bin/valkey-cli" } | OutputBin,
    valkey-benchmark = { glob = "usr/bin/valkey-benchmark" } | OutputBin,
    valkey-check-aof = { glob = "usr/bin/valkey-check-aof" } | OutputBin,
    valkey-check-rdb = { glob = "usr/bin/valkey-check-rdb" } | OutputBin,
    valkey-sentinel = { glob = "usr/bin/valkey-sentinel" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      # valkey itself is BSD-3-Clause (COPYING). The rest is what REUSE.toml assigns to
      # code linked into these binaries: deps/linenoise, deps/lz4, lzf (BSD-2-Clause),
      # deps/lua and setproctitle.c (MIT), sha1/sha256/siphash and deps/hdr_histogram
      # (CC0-1.0, hdr_histogram also BSD-2-Clause), deps/fpconv (BSL-1.0), crcspeed and
      # crccombine (Zlib), strl.c (ISC). deps/jemalloc (MALLOC=libc) and deps/fast_float
      # (USE_FAST_FLOAT unset) are not built.
      license_spdx = "BSD-3-Clause AND BSD-2-Clause AND MIT AND CC0-1.0 AND BSL-1.0 AND Zlib AND ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "valkey-io",
        repo = "valkey",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              for b in valkey-server valkey-cli valkey-benchmark; do
                v="$($b --version)"
                printf '%s\n' "$v"
                grep -qE '(v=| )%{version}( |$)' <<<"$v"
              done
              # The redis compat links are not shipped (see outputs).
              for b in redis-server redis-cli redis-benchmark; do
                ! command -v "$b"
              done
            "%
          ],
        ],
      } | Test,
    # A key written through valkey-cli reads back through a second connection.
    set_get =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-server}
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" SET lab:key 'hello valkey')" = OK ]
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" GET lab:key)" = 'hello valkey' ]
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" INCRBY lab:n 41)" = 41 ]
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" INCR lab:n)" = 42 ]
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" DBSIZE)" = 2 ]
            "%
          ],
        ],
      } | Test,
    # A short valkey-benchmark run: every SET and GET request completes, each test
    # reports a positive request rate, and the SETs really reached the server.
    benchmark =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, gawk, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-server}
              valkey-benchmark -h 127.0.0.1 -p "$port" -t set,get -n 2000 -c 4 -r 100 --csv > bench.csv
              cat bench.csv
              for t in SET GET; do
                awk -F'"' -v t="$t" '$2 == t && $4 + 0 > 0 { ok = 1 } END { exit !ok }' bench.csv
              done
              keys="$(valkey-cli -h 127.0.0.1 -p "$port" DBSIZE)"
              echo "keys after benchmark: $keys"
              [ "$keys" -ge 1 ]
              [ "$(valkey-cli -h 127.0.0.1 -p "$port" INFO commandstats | grep -o '^cmdstat_set:calls=[0-9]*' | cut -d= -f2)" -ge 2000 ]
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
