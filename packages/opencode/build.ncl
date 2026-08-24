let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bun = import "../bun/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in

let version = "1.18.14" in
{
  name = "opencode",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/anomalyco/opencode/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "3454d738eca7117099d6dc2a1d6330e0ac099da60cf3d8e40e8913ff3e38f656",
    } | Source,
    # #47: pre-materialized node_modules for the WHOLE workspace monorepo so
    # the offline `bun install --frozen-lockfile` is a NO-OP verify (zero
    # network). A cold bun install always hits the registry for metadata even
    # with a populated cache; only a lockfile-matching node_modules avoids it.
    # The root install verifies the entire workspace, so this carries the full
    # tree (root + every packages/*/node_modules). Staged via
    # `orch stage bun opencode --node-modules --use-fetcher` (built on the
    # fetcher VM, ~700M). build.sh extracts it into the source dir. extract=false.
    {
      url = "https://minimal.dev/generated/opencode-allnm-%{version}.tar.gz",
      sha256 = "de90c93e0b130a2b2515c3ded6f82c05184263eb21842189030562cbd7de754d",
      extract = false,
    } | Source,
    # #47 offline: models.dev/api.json snapshot for script/generate.ts; build.sh
    # exports MODELS_DEV_API_JSON pointing at this (hydrated to /build, extract=false).
    {
      url = "https://minimal.dev/generated/models-dev-api.json",
      sha256 = "f0bee6e56f7c7d5f3cad5a9cc5117cf51a5437f371f3ebb6896acde078500719",
      extract = false,
    } | Source,
    base,
    bun,
  ],

  runtime_deps = [
    glibc,
    git,
    ripgrep,
  ],

  # Hermetic: node_modules is pre-materialized (the bun-allnm Source above),
  # so the build needs no network. internet dropped (#47) — any network
  # attempt now fails loud instead of silently falling back to online.
  needs =
    {
      dns = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    opencode = { glob = "usr/bin/opencode" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      build_cost_multiple = 3,
      source_provenance = {
        category = 'GithubRepo,
        owner = "anomalyco",
        repo = "opencode",
      },
      env_dir_mappings = [
        { read_only = false, path = "~/.local/share/opencode", class = 'State },
        { read_only = false, path = "~/.config/opencode", class = 'State },
      ],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/opencode --version",
  },
} | BuildSpec
