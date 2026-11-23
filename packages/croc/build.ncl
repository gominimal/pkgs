# Imported from Wolfi `croc` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "11.6.6" in
{
  name = "croc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/schollz/croc/v%{version}.tar.gz",
      sha256 = "7b70ea161a1d6343b4499c81280d9650fadb1c298d3be96bbc54a2e8d8cd0c21",
      extract = true,
      strip_prefix = "croc-%{version}",
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
    croc = { glob = "usr/bin/croc" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "schollz", repo = "croc" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "croc --version"],
          ["/bin/bash", "-c", "croc --help"],
        ],
      } | Test,
  },
} | BuildSpec
