let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "83.0.0" in
{
  name = "setuptools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/setuptools-%{version}.tar.gz",
      sha256 = "188917862e785dc039fbc353b809ff185237411101fa270241034a6ec0e4f44b"
    } | Source,
    base,
    python,
    toolchain,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    site_packages = { glob = "usr/lib/python*/site-packages/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "setuptools",
      },
    } | Attrs,
} | BuildSpec
