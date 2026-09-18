# Auto-bootstrapped from https://github.com/pressly/goose by `pkgmgr import github` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "3.28.0" in
{
  name = "goose",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pressly/goose/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "71644c9d60710096ecc721edba4edf44e1f53cd0417564321c4b848e26c75bfa",
      extract = true,
      strip_prefix = "goose-%{version}",
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
    goose = { glob = "usr/bin/goose" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pressly", repo = "goose" },
      # TODO: REVIEWER — set license_spdx.
    } | Attrs,
} | BuildSpec
