let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "84.0.0" in
{
  name = "setuptools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/setuptools-%{version}.tar.gz",
      sha256 = "1cdd0d67229315c742282343f265cac91bb0976f83b2cf78dfa2f4a14343fe2a"
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
