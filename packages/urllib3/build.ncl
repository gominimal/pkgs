# Imported from Wolfi `urllib3` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let hatchling = import "../hatchling/build.ncl" in
let setuptools-scm = import "../setuptools-scm/build.ncl" in
let hatch-vcs = import "../hatch-vcs/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2.7.0" in
{
  name = "urllib3",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/urllib3/urllib3/%{version}.tar.gz",
      sha256 = "74317bc088603618b7bd9a57d7f3a043cef29123b672a5c280d373f5b3a8c317",
      extract = true,
      strip_prefix = "urllib3-%{version}",
    } | Source,
    base,
    hatchling,
    setuptools-scm,
    hatch-vcs,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/urllib3/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/urllib3-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "urllib3", repo = "urllib3" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
