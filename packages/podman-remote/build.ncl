# Auto-bootstrapped from https://github.com/containers/podman by `pkgmgr import github` (go build).
let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "6.1.4" in
{
  name = "podman-remote",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/podman-container-tools/podman/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "200fd9b4b6d820cae24fc99d8e290ec945512365cf3cda8283b3905c0c284ea8",
      extract = true,
      strip_prefix = "podman-%{version}",
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
    bin = { glob = "usr/bin/podman-remote" } | OutputBin,
  },
  # CGO_ENABLED=0: a static binary with no DT_NEEDED, so nothing at runtime.
  runtime_deps = [],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "podman-container-tools", repo = "podman" },
      license_spdx = "Apache-2.0",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/podman-remote --version",
  },
} | BuildSpec
