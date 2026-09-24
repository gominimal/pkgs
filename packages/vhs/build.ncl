let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.12.0" in
{
  name = "vhs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/charmbracelet/vhs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2e4a3b940f66ffbe1f66ded3b6253c9f3185a69567596e80d08c50cee77eaedf",
      extract = true,
      strip_prefix = "vhs-%{version}",
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
    vhs = { glob = "usr/bin/vhs" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "charmbracelet", repo = "vhs" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
