# Auto-bootstrapped from https://github.com/containers/podman by `pkgmgr import github` (go build).
let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "6.2.1" in
{
  name = "podman-remote",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/podman-container-tools/podman/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "10a56f6a36c4f7ea19956d7298615a6ff1f46978fc36d31dfe31be14899d10fb",
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
