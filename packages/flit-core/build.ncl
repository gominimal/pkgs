let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

let version = "3.12.0" in
{
  name = "flit-core",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://pypi.org/packages/source/f/flit-core/flit_core-%{version}.tar.gz",
      sha256 = "18f63100d6f94385c6ed57a72073443e1a71a4acb4339491615d0f16d6ff01b2",
      extract = true,
      strip_prefix = "flit_core-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python3.13/site-packages/flit_core/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/flit_core-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "flit",
      },
    } | Attrs,
} | BuildSpec
