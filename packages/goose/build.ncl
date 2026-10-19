# Auto-bootstrapped from https://github.com/pressly/goose by `pkgmgr import github` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "3.29.0" in
{
  name = "goose",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pressly/goose/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "267124956365ab3ed32ec9e36f4f341050916ed69fd2c4fbfc42355bb7fbf66f",
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
      # Verified against the LICENSE file at the v3.29.0 tag pinned above.
      license_spdx = "MIT",
      source_provenance = { category = 'GithubRepo, owner = "pressly", repo = "goose" },
    } | Attrs,
} | BuildSpec
