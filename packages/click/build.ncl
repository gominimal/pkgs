# Imported from Wolfi `click` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "8.4.2" in
{
  name = "click",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pallets/click/%{version}.tar.gz",
      sha256 = "d5635f9b7999806a02bd323fc7a9f8c4b1cb5f600b2967d4e7e5dbb106b1c216",
      extract = true,
      strip_prefix = "click-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/click/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/click-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pallets", repo = "click" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
} | BuildSpec
