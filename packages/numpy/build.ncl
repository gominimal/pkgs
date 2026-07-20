let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cython = import "../cython/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let meson-python = import "../meson-python/build.ncl" in

let python = import "../python/build.ncl" in
let openblas = import "../openblas/build.ncl" in

let version = "2.5.1" in
{
  name = "numpy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/n/numpy/numpy-%{version}.tar.gz",
      sha256 = "a48a113e6afea91f5608793bafa7ef2ad481fefbda87ec5069f483de61cb9fa3",
      extract = true,
      strip_prefix = "numpy-%{version}",
    } | Source,
    base,
    cython,
    pkgconf,
    meson-python,
  ],

  runtime_deps = [
    python,
    openblas,
  ],

  cmd = "./build.sh",

  outputs = {
    f2py = { glob = "usr/bin/f2py" } | OutputBin,
    numpy-config = { glob = "usr/bin/numpy-config" } | OutputBin,

    python_site_package = { glob = "usr/lib/python*/site-packages/numpy/**", allow_executable = true } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/numpy-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "numpy",
        repo = "numpy",
      },
    } | Attrs,
} | BuildSpec
