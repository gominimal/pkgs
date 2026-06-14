let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.1.4" in
{
  name = "govulncheck",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golang/vuln/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "da1a7f3224cf874325814dd198eaa42897143fc871226a04944583cb121a15c9",
      extract = true,
    } | Source,
    base,
    go,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    govulncheck = { glob = "usr/bin/govulncheck" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "vuln",
      },
    } | Attrs,
} | BuildSpec
