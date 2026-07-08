# Imported from Wolfi `certifi` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2026.06.17" in
{
  name = "certifi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/certifi/python-certifi/%{version}.tar.gz",
      sha256 = "de76d4c70f5a4fecce2522a11e01b57ea75d41d878bc590dcc43290d26a0acc8",
      extract = true,
      strip_prefix = "python-certifi-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/certifi/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/certifi-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "certifi", repo = "python-certifi" },
      license_spdx = "MPL-2.0",
    } | Attrs,
} | BuildSpec
