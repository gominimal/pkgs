let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in

let version = "1.2.0" in
{
  name = "pyproject-hooks",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyproject-hooks/pyproject_hooks-%{version}.tar.gz",
      sha256 = "1e859bd5c40fae9448642dd871adf459e5e2084186e8d2c2a79a824c970da1f8",
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
    python_site_package = { glob = "usr/lib/python3.13/site-packages/pyproject_hooks/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/pyproject_hooks-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
