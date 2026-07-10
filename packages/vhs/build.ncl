# Auto-bootstrapped from https://github.com/charmbracelet/vhs by `pkgmgr bootstrap` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.11.0" in
{
  name = "vhs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/charmbracelet/vhs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "c08b8502989fe7e9626c02938f3fc512c2a4ba21f839f455d20d7eb1da7bc39f",
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
