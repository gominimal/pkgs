let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let boost = import "../boost/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let mono = import "../mono/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "7.3.69" in
{
  name = "foundationdb",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/apple/foundationdb/archive/refs/tags/%{version}.tar.gz",
      sha256 = "1dcee96cae02d76c43578a9fcaad937b7cbda401dc6dd6c47d4096bce4f6fadb",
      extract = true,
      strip_prefix = "foundationdb-%{version}",
    } | Source,
    base,
    boost,
    cmake,
    git,
    mono,
    ninja,
    openssl,
    pkgconf,
    python,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    openssl,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  needs = {
    internet = {},
    dns = {},
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libfdb_c*.so*" } | OutputLib,
    includes = { glob = "usr/include/foundationdb/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/FoundationDB-Client/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/foundationdb-client.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "apple",
        repo = "foundationdb",
      },
      build_cost_multiple = 4,
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/fdbcli --version",

    server_smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
            set -euo pipefail

            # Create a minimal FDB cluster file
            TMPDIR=$(mktemp -d)
            CLUSTER_FILE="$TMPDIR/fdb.cluster"
            DATA_DIR="$TMPDIR/data"
            LOG_DIR="$TMPDIR/logs"
            mkdir -p "$DATA_DIR" "$LOG_DIR"

            echo "test:testid@127.0.0.1:4500" > "$CLUSTER_FILE"

            # Start fdbserver in the background
            /bin/fdbserver \
              -p auto:4500 \
              -C "$CLUSTER_FILE" \
              -d "$DATA_DIR" \
              -L "$LOG_DIR" &
            SERVER_PID=$!

            # Wait for server to start
            sleep 2

            # Configure the database as a new single-process cluster
            /bin/fdbcli -C "$CLUSTER_FILE" --exec "configure new single memory"

            # Wait for database to be ready
            sleep 1

            # Write and read back a key
            /bin/fdbcli -C "$CLUSTER_FILE" --exec "writemode on; set testkey testvalue"
            RESULT=$(/bin/fdbcli -C "$CLUSTER_FILE" --exec "get testkey")

            # Verify result contains the value
            echo "$RESULT" | grep -q "testvalue"

            # Clean shutdown
            kill $SERVER_PID
            wait $SERVER_PID 2>/dev/null || true

            echo "FoundationDB smoke test passed"
          "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
