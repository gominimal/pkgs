let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bun = import "../bun/build.ncl" in

let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.14.0" in
{
  name = "hunk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/modem-dev/hunk/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "8cb99e7366eddc82d1ccc754c9cdf4b55c64244929094e49571fad1b80ce759c",
      extract = true,
      strip_prefix = "hunk-%{version}",
    } | Source,
    # #47: pre-materialized node_modules so the offline `bun install
    # --frozen-lockfile` is a NO-OP verify (zero network). A cold bun install
    # always contacts the registry for metadata even with a populated cache,
    # so the offline build would hang on the blackholed connect(); only a
    # lockfile-matching node_modules avoids the network. Staged via
    # `orch stage bun hunk --node-modules`. build.sh extracts it into /build.
    # extract=false.
    {
      url = "https://minimal.dev/generated/hunk-allnm-%{version}.tar.gz",
      sha256 = "c8d3d7c542d2fec31435c001af3e12b2def7dc6d25334227c2d653cfdad9c292",
      extract = false,
    } | Source,
    base,
    bun,
  ],

  runtime_deps = [
    glibc,
    git,
  ],

  # Hermetic: node_modules is pre-materialized (above), so the build needs
  # no network. internet dropped (#47) — any network attempt now fails loud
  # instead of silently falling back to an online install.
  needs =
    {
      dns = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    hunk = { glob = "usr/bin/hunk" } | OutputBin,
    hunkdiff = { glob = "usr/bin/hunkdiff" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "modem-dev",
        repo = "hunk",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/hunk --version",
  },
} | BuildSpec
