# Imported from Wolfi `six` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "1.17.0" in
{
  name = "six",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/benjaminp/six/%{version}.tar.gz",
      sha256 = "32f3ae8f39a23ff9458d84c90e00cf042e5432ccb61c8991a5e437e7eacd83c6",
      extract = true,
      strip_prefix = "six-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    site_six = { glob = "usr/lib/python*/site-packages/six.py" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/six-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "benjaminp", repo = "six" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
