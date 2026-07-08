# Imported from Wolfi `python-dateutil` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let six = import "../six/build.ncl" in
let version = "2.9.0" in
{
  name = "python-dateutil",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dateutil/dateutil/%{version}.tar.gz",
      sha256 = "f98616d970b4db272a66ce4b0bf04529ed4b26549f070a4dd9481d0a536293bf",
      extract = true,
      strip_prefix = "dateutil-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/dateutil/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/python_dateutil-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, six],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "dateutil", repo = "dateutil" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
