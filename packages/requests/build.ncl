# Imported from Wolfi `requests` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let charset-normalizer = import "../charset-normalizer/build.ncl" in
let idna = import "../idna/build.ncl" in
let urllib3 = import "../urllib3/build.ncl" in
let certifi = import "../certifi/build.ncl" in
let version = "2.34.2" in
{
  name = "requests",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/psf/requests/v%{version}.tar.gz",
      sha256 = "d3c132d905099fa3468bb5cb273c2bdf5a7a92dce987c93b198820b3a7b57228",
      extract = true,
      strip_prefix = "requests-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/requests/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/requests-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, charset-normalizer, idna, urllib3, certifi],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "psf", repo = "requests" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
