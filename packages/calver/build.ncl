# Imported from Wolfi `calver` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2025.10.20" in
{
  name = "calver",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/di/calver/%{version}.tar.gz",
      sha256 = "8378c74d31e7d04ab1fd00f0a0d128525941823134c1e79dbcd649d3c130fc03",
      extract = true,
      strip_prefix = "calver-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/calver/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/calver-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, setuptools],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "di", repo = "calver" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
