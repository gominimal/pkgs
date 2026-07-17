let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.6.0" in
{
  name = "govulncheck",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golang/vuln/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "70f82d70f3a6757babbeb4e6834536e572d1c822180619ac74b649e3e4f247fb",
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
