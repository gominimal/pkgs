# Imported from Wolfi `charset-normalizer` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "3.4.9" in
{
  name = "charset-normalizer",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/jawah/charset_normalizer/%{version}.tar.gz",
      sha256 = "5b7bcc5c09e1e8c1ba0173bbb829385bde1dc8e2f8f47230a690f27882b755d2",
      extract = true,
      strip_prefix = "charset_normalizer-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    normalizer = { glob = "usr/bin/normalizer" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/charset_normalizer/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/charset_normalizer-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "jawah", repo = "charset_normalizer" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "normalizer --help"],
          ["/bin/bash", "-c", "normalizer --version"],
          ["/bin/bash", "-c", "normalizer --version"],
        ],
      } | Test,
  },
} | BuildSpec
