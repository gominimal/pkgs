let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.12.1" in
{
  name = "vhs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/charmbracelet/vhs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ba9fbcb40133d1734c580ccb6b0fcae9673bf51d227f00877ac581c56ad15b77",
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
