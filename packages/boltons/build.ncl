# Imported from Wolfi `boltons` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "26.0.0" in
{
  name = "boltons",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mahmoud/boltons/%{version}.tar.gz",
      sha256 = "c1b7eb5fd76e04093b5c0151ca1ac4b064faf4b736eaf1c0c83a8de101ccae14",
      extract = true,
      strip_prefix = "boltons-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/boltons/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/boltons-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "mahmoud", repo = "boltons" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
} | BuildSpec
