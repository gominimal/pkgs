# Imported from Wolfi `mdurl` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "0.1.2" in
{
  name = "mdurl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/executablebooks/mdurl/%{version}.tar.gz",
      sha256 = "99d4fabddab7ee4a05fa458deb1a6f0d009966e4631c50d1b875767a1cd3896d",
      extract = true,
      strip_prefix = "mdurl-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/mdurl/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/mdurl-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "executablebooks", repo = "mdurl" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
