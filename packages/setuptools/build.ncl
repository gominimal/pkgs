let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "84.2.1" in
{
  name = "setuptools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/setuptools-%{version}.tar.gz",
      sha256 = "99f6fbe42e4857bf52f43915a9505e2a9d1439f9c7652823a22822fd73d35bb0"
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
