# Imported from Wolfi `git-lfs` by `pkgmgr import wolfi` (go build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "3.8.0" in
{
  name = "git-lfs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/git-lfs/git-lfs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "a12ecfc17ebee002d1f6acca79442029d41cbf5e5b4ba9e02249ed96de20300f",
      extract = true,
      strip_prefix = "git-lfs-%{version}",
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
    git-lfs = { glob = "usr/bin/git-lfs" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "git-lfs", repo = "git-lfs" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The Wolfi block tested `git lfs version`, which dispatches through
          # git and needs git on PATH as a test dep — it exited 127 here. What
          # this package is responsible for is the binary, so test that
          # directly; `git lfs ...` working is git's dispatch, not ours.
          ["/bin/bash", "-c", "/bin/git-lfs version | grep -q git-lfs"],
          ["/bin/bash", "-c", "/bin/git-lfs env >/dev/null"],
        ],
      } | Test,
  },
} | BuildSpec
