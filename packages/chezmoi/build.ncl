let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.71.1" in
{
  name = "chezmoi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/twpayne/chezmoi/v%{version}.tar.gz",
      sha256 = "ecbba845ef7b924c510d32a7342727b9889cc8c77a289e3a04b777226ef8938c",
      extract = true,
      strip_prefix = "chezmoi-%{version}",
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
  build_args = {
    include version,
  },
  outputs = {
    chezmoi = { glob = "usr/bin/chezmoi" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "twpayne", repo = "chezmoi" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Version/help smoke checks. The Wolfi recipe's dotfile-flow tests
          # (chezmoi init/add/apply/data/doctor) need a writable $HOME + git
          # and aren't portable to the standalone sandbox — dropped.
          ["/bin/bash", "-c", "chezmoi --version 2>/dev/null || chezmoi version"],
          ["/bin/bash", "-c", "chezmoi --help 2>/dev/null || chezmoi help"],
        ],
      } | Test,
  },
} | BuildSpec
