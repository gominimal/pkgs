# Imported from Wolfi `trove-classifiers` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let setuptools-scm = import "../setuptools-scm/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2026.6.1.19" in
{
  name = "trove-classifiers",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pypa/trove-classifiers/%{version}.tar.gz",
      sha256 = "20360c44ddae1f970eab52c26523de6e2e79bbe7c493fa363c681ee5fa47a588",
      extract = true,
      strip_prefix = "trove-classifiers-%{version}",
    } | Source,
    base,
    setuptools,
    setuptools-scm,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    trove-classifiers = { glob = "usr/bin/trove-classifiers" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/trove_classifiers/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/trove_classifiers-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pypa", repo = "trove-classifiers" },
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "trove-classifiers"],
        ],
      } | Test,
  },
} | BuildSpec
