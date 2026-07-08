# Imported from Wolfi `idna` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "3.18" in
{
  name = "idna",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/kjd/idna/v%{version}.tar.gz",
      sha256 = "d51d4068b4e8bac335589797266b0af8ced2be9fb5d5cc2a887ee64e2f5b28a9",
      extract = true,
      strip_prefix = "idna-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    idna = { glob = "usr/bin/idna" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/idna/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/idna-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "kjd", repo = "idna" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
} | BuildSpec
