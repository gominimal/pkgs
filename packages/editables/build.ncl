# Imported from Wolfi `editables` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "0.6" in
{
  name = "editables",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pfmoore/editables/%{version}.tar.gz",
      sha256 = "766d9b40616dbcf5cc920e9db26dd915de999cfab75768ff05b3ebf9c389acb2",
      extract = true,
      strip_prefix = "editables-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/editables/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/editables-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pfmoore", repo = "editables" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
