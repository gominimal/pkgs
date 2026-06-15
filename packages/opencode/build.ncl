let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bun = import "../bun/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in

let version = "1.14.20" in
{
  name = "opencode",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/anomalyco/opencode/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cfa02650be42398be8b8f813ac4736a25d4a8d8a5f92b035bd98b66b4afcd34a",
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
      sha256 = "06a2ca8f1fee73deb617d87f2f812952f7c8f8a42d607f853195f53e76a89038",
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
