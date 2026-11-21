# Auto-bootstrapped from https://github.com/go-swagger/go-swagger by `pkgmgr import github` (go build).
let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.36.8" in
{
  name = "go-swagger",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/go-swagger/go-swagger/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "88e6be5f201e9039a78d818cda7cf5b13c411085701c02001b385c2c6978963c",
      extract = true,
      strip_prefix = "go-swagger-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    go-swagger = { glob = "usr/bin/swagger" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "go-swagger", repo = "go-swagger" },
      license_spdx = "Apache-2.0",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/swagger version",
  },
} | BuildSpec
