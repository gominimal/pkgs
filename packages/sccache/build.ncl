# Imported from Wolfi `sccache` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.18.0" in
{
  name = "sccache",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-111943 (eMudhra intermediate key compromise): pins rustls-webpki
    # 0.103.16 (RUSTSEC-2026-0382, distrusts the 8 intermediates) and
    # webpki-roots / webpki-root-certs 1.0.10 (RUSTSEC-2026-0383, drops emSign ECC
    # Root CA - G3) in upstream's Cargo.lock, and moves the standalone
    # webpki-roots 0.26.2 (its own pre-distrust root list, via hyper-rustls) to
    # the 0.26.11 shim over webpki-roots 1.x. rustls-webpki 0.103.16 needs
    # aws-lc-rs ^1.18 (-> 1.18.0, which needs aws-lc-sys ^0.44 -> 0.44.0, which
    # needs pkg-config ^0.3.31 -> 0.3.32), so those move with it. Lock-only:
    # versions, checksums, dependency references. Regenerated for 0.18.0 (pkgs#997).
    # Drop on the first upstream
    # release whose Cargo.lock already has those versions; a version bump that
    # keeps it fails at `patch` rather than silently shipping the old lock.
    { file = "cve-2026-111943-webpki-lock.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/mozilla/sccache/v%{version}.tar.gz",
      sha256 = "14e37fc2cb4f21c188789d518e170181b7cd1ba523152880cdf8009269d79732",
      extract = true,
      strip_prefix = "sccache-%{version}",
    } | Source,
    base,
    patch,
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
