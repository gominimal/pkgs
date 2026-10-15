# Auto-bootstrapped from https://github.com/containers/podman by `pkgmgr import github` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "6.1.3" in
{
  name = "podman-remote",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/podman-container-tools/podman/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6253aee14e573f747ca77e5a83a0df4ef9c2f609604f56715070ed06b6f9ddd8",
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
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "podman-container-tools", repo = "podman" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
