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
    base,
    bun,
  ],

  runtime_deps = [
    glibc,
    git,
    ripgrep,
  ],

  needs =
    {
      dns = {},
      internet = {},
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
