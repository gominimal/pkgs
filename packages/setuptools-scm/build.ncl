# Imported from Wolfi `setuptools-scm` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in
let typing-extensions = import "../typing-extensions/build.ncl" in
let version = "9.2.2" in
{
  name = "setuptools-scm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pypa/setuptools_scm/v%{version}.tar.gz",
      sha256 = "853f06f1ab2cebd2bef6970c76fdf6bd6bad250c69b9d966d5a3e14f9d503df1",
      extract = true,
      strip_prefix = "setuptools-scm-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    setuptools-scm = { glob = "usr/bin/setuptools-scm" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/setuptools_scm/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/setuptools_scm-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, py-packaging, setuptools, typing-extensions],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pypa", repo = "setuptools_scm" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "setuptools-scm --help"],
        ],
      } | Test,
  },
} | BuildSpec
