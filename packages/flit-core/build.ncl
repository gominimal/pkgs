let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

let version = "4.1.0" in
{
  name = "flit-core",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://pypi.org/packages/source/f/flit-core/flit_core-%{version}.tar.gz",
      sha256 = "62e12b63ead8335b37f59fabb977c7167fe476dafb5e41785dfa8c9aff843bc6",
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
    python_site_package = { glob = "usr/lib/python*/site-packages/flit_core/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/flit_core-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "flit",
      },
    } | Attrs,
} | BuildSpec
