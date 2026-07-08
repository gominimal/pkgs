# Imported from Wolfi `wrapt` by `pkgmgr import-wolfi` (python build).
# TODO: REVIEWER — verify the pypi runtime deps (install_requires) + outputs.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let python = import "../python/build.ncl" in
let version = "2.2.2" in
{
  name = "wrapt",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/GrahamDumpleton/wrapt/%{version}.tar.gz",
      sha256 = "e37dec1263084cef183d1a00118f9113bcad7837332b6036aef835cc349aa360",
      extract = true,
      strip_prefix = "wrapt-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "GrahamDumpleton", repo = "wrapt" },
      license_spdx = "BSD-2-Clause",
    } | Attrs,
} | BuildSpec
