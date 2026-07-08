# Imported from Wolfi `distro` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "1.9.0" in
{
  name = "distro",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/python-distro/distro/v%{version}.tar.gz",
      sha256 = "6ede051357868ed427ea71d16fc27f4d63cc0d9c8a32788aa11c450ecefcc76f",
      extract = true,
      strip_prefix = "distro-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/distro/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/distro-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "python-distro", repo = "distro" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
