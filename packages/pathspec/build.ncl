# Imported from Wolfi `pathspec` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "1.1.1" in
{
  name = "pathspec",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/cpburnz/python-pathspec/v%{version}.tar.gz",
      sha256 = "7befd398baeb84cd3872bcb84926e688361012d21c8c157dcc2f9f64684b9147",
      extract = true,
      strip_prefix = "python-pathspec-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/pathspec/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pathspec-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "cpburnz", repo = "python-pathspec" },
      license_spdx = "MPL-2.0",
    } | Attrs,
} | BuildSpec
