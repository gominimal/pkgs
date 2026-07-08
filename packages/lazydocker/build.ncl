# Imported from Wolfi `lazydocker` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.25.2" in
{
  name = "lazydocker",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/jesseduffield/lazydocker/v%{version}.tar.gz",
      sha256 = "405071220e5be9aa061c65d290e0347143b73ae0a3cc01df164f0105de2b53c4",
      extract = true,
      strip_prefix = "lazydocker-%{version}",
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
    lazydocker = { glob = "usr/bin/lazydocker" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "jesseduffield", repo = "lazydocker" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "lazydocker --help"],
          ["/bin/bash", "-c", "lazydocker --version"],
        ],
      } | Test,
  },
} | BuildSpec
