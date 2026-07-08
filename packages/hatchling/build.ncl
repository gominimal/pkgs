# Imported from Wolfi `hatchling` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in
let pathspec = import "../pathspec/build.ncl" in
let pluggy = import "../pluggy/build.ncl" in
let trove-classifiers = import "../trove-classifiers/build.ncl" in
let version = "1.31.0" in
{
  name = "hatchling",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pypa/hatch/hatchling-v%{version}.tar.gz",
      sha256 = "7432f025f7d641a7e5ced035b712d67895ab31ba487f127163683ae26f51b90e",
      extract = true,
      strip_prefix = "hatch-hatchling-v%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    hatchling = { glob = "usr/bin/hatchling" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/hatchling/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/hatchling-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python, py-packaging, pathspec, pluggy, trove-classifiers],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pypa", repo = "hatch" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
