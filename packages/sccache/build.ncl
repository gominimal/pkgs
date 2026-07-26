# Imported from Wolfi `sccache` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.16.0" in
{
  name = "sccache",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mozilla/sccache/v%{version}.tar.gz",
      sha256 = "917fd4d7e584c23dd3cf9ca2f394c2ca03c57c73e2d6079770f07d9008176afe",
      extract = true,
      strip_prefix = "sccache-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    make,
    openssl,
    pkgconf,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    sccache = { glob = "usr/bin/sccache" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"], openssl],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "mozilla", repo = "sccache" },
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "sccache --version\nsccache --help"],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Start the sccache server\nsccache --start-server\n\n# Verify server is running by showing stats\nsccache --show-stats\n\n# Stop the server\nsccache --stop-server"],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Start a fresh server\nsccache --start-server\n\n# Show stats and verify output contains expected fields\nstats_output=$(sccache --show-stats)\necho \"$stats_output\" | grep -iF \"cache\"\n\n# Clean up\nsccache --stop-server"],
        ],
      } | Test,
  },
} | BuildSpec
