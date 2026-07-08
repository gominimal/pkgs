# Imported from Wolfi `markupsafe` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in
let version = "3.0.3" in
{
  name = "markupsafe",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pallets/markupsafe/%{version}.tar.gz",
      sha256 = "f1d9d06c34515dd3ad210ec769da613057b536d11d6c039183b87757a883a254",
      extract = true,
      strip_prefix = "markupsafe-%{version}",
    } | Source,
    base,
    setuptools,
    toolchain,
    python,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/markupsafe/**", allow_executable = true } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/markupsafe-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pallets", repo = "markupsafe" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
} | BuildSpec
