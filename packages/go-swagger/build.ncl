# Auto-bootstrapped from https://github.com/go-swagger/go-swagger by `pkgmgr import github` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.36.6" in
{
  name = "go-swagger",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/go-swagger/go-swagger/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e74772227718a6e022b12542929e983b419635279666227fdc09fb92b8533594",
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
} | BuildSpec
