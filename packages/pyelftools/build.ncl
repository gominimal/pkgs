let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in

let version = "0.33" in
{
  name = "pyelftools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyelftools/pyelftools-%{version}.tar.gz",
      sha256 = "660d82dcbeb8e83d1702bd97f223f761625da06111c0cc988eac6b8ab0c1b61f",
      extract = true,
      strip_prefix = "pyelftools-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    setuptools,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/elftools/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pyelftools-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "eliben",
        repo = "pyelftools",
      },
    } | Attrs,
} | BuildSpec
