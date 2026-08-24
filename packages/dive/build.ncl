# Imported from Wolfi `dive` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.13.1" in
{
  name = "dive",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/wagoodman/dive/v%{version}.tar.gz",
      sha256 = "2a9666e9c3fddd5e2e5bad81dccda520b8102e7cea34e2888f264b4eb0506852",
      extract = true,
      strip_prefix = "dive-%{version}",
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
    dive = { glob = "usr/bin/dive" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/dive" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_dive" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/dive.fish" } | OutputData,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "wagoodman", repo = "dive" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "dive --version\ndive --help"],
        ],
      } | Test,
  },
} | BuildSpec
