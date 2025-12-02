let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let packaging = import "../packaging/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "1.3.0" in
{
  name = "build",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/b/build/build-%{version}.tar.gz",
      sha256 = "698edd0ea270bde950f53aed21f3a0135672206f3911e0176261a31e0e07b397",
      extract = true,
      strip_prefix = "build-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    packaging,
    pyproject-hooks,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python3.13/site-packages/build/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/build-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
