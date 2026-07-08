# Imported from Wolfi `pygments` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let hatchling = import "../hatchling/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2.20.0" in
{
  name = "pygments",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pygments/pygments/%{version}.tar.gz",
      sha256 = "da22a0d6df2abb3bcf6815a0612e5b1b05b4c3fd0a5e804ae79c271de2fe50b1",
      extract = true,
      strip_prefix = "pygments-%{version}",
    } | Source,
    base,
    hatchling,
  ],
  cmd = "./build.sh",
  outputs = {
    pygmentize = { glob = "usr/bin/pygmentize" } | OutputBin,
    python_site_package = { glob = "usr/lib/python*/site-packages/pygments/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pygments-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "pygments", repo = "pygments" },
      license_spdx = "BSD-2-Clause",
    } | Attrs,
} | BuildSpec
