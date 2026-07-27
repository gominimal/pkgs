let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bun = import "../bun/build.ncl" in

let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.17.4" in
{
  name = "hunk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/modem-dev/hunk/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f37c7e7c492a60f8b4a49cf99581de2dcb6e1c5ba120703790ae55bc596072d5",
      extract = true,
      strip_prefix = "hunk-%{version}",
    } | Source,
    base,
    bun,
  ],

  runtime_deps = [
    glibc,
    git,
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
