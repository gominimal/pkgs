# Auto-bootstrapped from https://github.com/pressly/goose by `pkgmgr import github` (go build).
let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "3.30.0" in
{
  name = "goose",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pressly/goose/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "60bcb9527ca286903c8f8e4cd19ce15597a7bb080e795166ea356a3e3d04a920",
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
      # Verified against the LICENSE file at the v3.30.0 tag pinned above.
      license_spdx = "MIT",
      source_provenance = { category = 'GithubRepo, owner = "pressly", repo = "goose" },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/goose --version",
  },
} | BuildSpec
