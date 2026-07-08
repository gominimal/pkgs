# Imported from Wolfi `more-itertools` by `pkgmgr import-wolfi` (python build).
# TODO: REVIEWER — verify the pypi runtime deps (install_requires) + outputs.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "11.1.0" in
{
  name = "more-itertools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/more-itertools/more-itertools/v%{version}.tar.gz",
      sha256 = "685e5ee4b97fc6d7bf8d2b920df48cb1a9ae410d447c2b63c3488674ac2b70a8",
      extract = true,
      strip_prefix = "more-itertools-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "more-itertools", repo = "more-itertools" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
