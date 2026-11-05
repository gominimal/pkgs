let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in

let version = "1.3.3" in
{
  name = "pyproject-hooks",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyproject-hooks/pyproject_hooks-%{version}.tar.gz",
      sha256 = "defda19b854fa0d3bd4f76ea4ddcba8abd7dcfcdd585a6690ade050744fc5f43",
      extract = true,
      strip_prefix = "pyproject_hooks-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    flit-core,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/pyproject_hooks/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pyproject_hooks-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "pyproject-hooks",
      },
    } | Attrs,
} | BuildSpec
