let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "82.0.1" in
{
  name = "setuptools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/setuptools-%{version}.tar.gz",
      sha256 = "7d872682c5d01cfde07da7bccc7b65469d3dca203318515ada1de5eda35efbf9"
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "setuptools",
      },
    } | Attrs,
} | BuildSpec
