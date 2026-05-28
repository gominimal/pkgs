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
