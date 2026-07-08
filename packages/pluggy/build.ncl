# Imported from Wolfi `pluggy` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let setuptools-scm = import "../setuptools-scm/build.ncl" in
let python = import "../python/build.ncl" in
let version = "1.6.0" in
{
  name = "pluggy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pytest-dev/pluggy/%{version}.tar.gz",
      sha256 = "d35ec78be56dae9fd736e1378a2c3c176fd2aefd9daefc209abeab569c2732ee",
      extract = true,
      strip_prefix = "pluggy-%{version}",
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
    python_site_package = { glob = "usr/lib/python*/site-packages/pluggy/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pluggy-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pytest-dev", repo = "pluggy" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
