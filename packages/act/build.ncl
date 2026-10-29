# Imported from Wolfi `act` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.2.92" in
{
  name = "act",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nektos/act/v%{version}.tar.gz",
      sha256 = "8b3ffbbb803007dfca19d5ea8e071876733d1390cfe358fe164ad67c6d7e549b",
      extract = true,
      strip_prefix = "act-%{version}",
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
    act = { glob = "usr/bin/act" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/act" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_act" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/act.fish" } | OutputData,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "nektos", repo = "act" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "act --version"],
          ["/bin/bash", "-c", "act --help"],
        ],
      } | Test,
  },
} | BuildSpec
