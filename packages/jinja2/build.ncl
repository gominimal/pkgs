# Imported from Wolfi `jinja2` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let markupsafe = import "../markupsafe/build.ncl" in
let version = "3.1.6" in
{
  name = "jinja2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pallets/jinja/%{version}.tar.gz",
      sha256 = "2074b22a72caa65474902234b320d73463d6d4c223ee49f4b433495758356337",
      extract = true,
      strip_prefix = "jinja-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/jinja2/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/jinja2-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, markupsafe],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pallets", repo = "jinja" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
} | BuildSpec
