# Imported from Wolfi `hatch-vcs` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let hatchling = import "../hatchling/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let setuptools-scm = import "../setuptools-scm/build.ncl" in
let version = "0.5.0" in
{
  name = "hatch-vcs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ofek/hatch-vcs/v%{version}.tar.gz",
      sha256 = "a74465d21bb60eef75f01b3c189b73181f152a5eef2b26bd95de039e224953a7",
      extract = true,
      strip_prefix = "hatch-vcs-%{version}",
    } | Source,
    base,
    hatchling,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/hatch_vcs/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/hatch_vcs-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, hatchling, setuptools, setuptools-scm],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ofek", repo = "hatch-vcs" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
