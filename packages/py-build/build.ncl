let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "1.6.1" in
{
  name = "py-build",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/b/build/build-%{version}.tar.gz",
      sha256 = "51cc11666391ab6f092070437ac747002ff46f3e4113a3622177ee6b488bfc53",
      extract = true,
      strip_prefix = "build-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    py-packaging,
    pyproject-hooks,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/build/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/build-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "build",
      },
    } | Attrs,
} | BuildSpec
