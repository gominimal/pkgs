let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in

let version = "0.12.1" in
{
  name = "pyproject-metadata",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyproject-metadata/pyproject_metadata-%{version}.tar.gz",
      sha256 = "8809a4df6fe08279b39a8890669506ed3158e0617855ac9aff098fcbe772ae4c",
      extract = true,
      strip_prefix = "pyproject_metadata-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    py-packaging,
    flit-core,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/pyproject_metadata/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pyproject_metadata-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "pyproject-metadata",
      },
    } | Attrs,
} | BuildSpec
