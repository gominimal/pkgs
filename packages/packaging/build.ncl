let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "25.0" in
{
  name = "packaging",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/packaging/packaging-%{version}.tar.gz",
      sha256 = "d443872c98d677bf60f6a1f2f8c1cb748e8fe762d2bf9d3148b5599295b0fc4f",
      extract = true,
      strip_prefix = "packaging-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    pyproject-hooks,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python3.13/site-packages/packaging/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/packaging-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
