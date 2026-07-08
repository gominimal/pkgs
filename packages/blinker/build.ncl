# Imported from Wolfi `blinker` by `pkgmgr import-wolfi` (python build).
# TODO: REVIEWER — verify the pypi runtime deps (install_requires) + outputs.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "1.9.0" in
{
  name = "blinker",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pallets-eco/blinker/%{version}.tar.gz",
      sha256 = "9b02df578ec0aadd5e800e5f09281e80abddab5e0f74b4b88694f06c9956b6aa",
      extract = true,
      strip_prefix = "blinker-%{version}",
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
      source_provenance = { category = 'GithubRepo, owner = "pallets-eco", repo = "blinker" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
