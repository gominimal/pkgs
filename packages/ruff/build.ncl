# Imported from Wolfi `ruff` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.15.22" in
{
  name = "ruff",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/astral-sh/ruff/%{version}.tar.gz",
      sha256 = "319db883d92d2aa140c244bd8fb2fc690f25b5a8fd37210b52e069ca0c1513ba",
      extract = true,
      strip_prefix = "ruff-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    make,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    ruff = { glob = "usr/bin/ruff" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "astral-sh", repo = "ruff" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "ruff --version"],
          ["/bin/bash", "-c", "ruff --help"],
          ["/bin/bash", "-c", "echo 'print(\"Hello, world!\")' > test.py\nruff check test.py || exit 1"],
          ["/bin/bash", "-c", "echo 'print(\"Hello, world!\")' > test.py\nruff check --select F401 test.py || exit 1"],
        ],
      } | Test,
  },
} | BuildSpec
