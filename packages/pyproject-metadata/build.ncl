let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let packaging = import "../packaging/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in

let version = "0.9.1" in
{
  name = "pyproject-metadata",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyproject-metadata/pyproject_metadata-%{version}.tar.gz",
      sha256 = "b8b2253dd1b7062b78cf949a115f02ba7fa4114aabe63fa10528e9e1a954a816",
      extract = true,
      strip_prefix = "pyproject_metadata-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    packaging,
    flit-core,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python3.13/site-packages/pyproject_metadata/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/pyproject_metadata-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
