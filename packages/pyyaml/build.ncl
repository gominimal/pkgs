# Imported from Wolfi `pyyaml` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in
let version = "6.0.3" in
{
  name = "pyyaml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/yaml/pyyaml/%{version}.tar.gz",
      sha256 = "c7b45011e052458ae79015d5eea3046c37d099023d4b253dde26ee1c29ea2f36",
      extract = true,
      strip_prefix = "pyyaml-%{version}",
    } | Source,
    base,
    setuptools,
    toolchain,
    python,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/_yaml/**", allow_executable = true } | OutputData,
    site_yaml = { glob = "usr/lib/python*/site-packages/yaml/**", allow_executable = true } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pyyaml-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "yaml", repo = "pyyaml" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
