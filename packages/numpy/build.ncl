let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cython = import "../cython/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let meson-python = import "../meson-python/build.ncl" in

let python = import "../python/build.ncl" in
let openblas = import "../openblas/build.ncl" in

let version = "2.3.5" in
{
  name = "numpy",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/n/numpy/numpy-%{version}.tar.gz",
      sha256 = "784db1dcdab56bf0517743e746dfb0f885fc68d948aba86eeec2cba234bdf1c0",
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

    python_site_package = { glob = "usr/lib/python3.13/site-packages/numpy/**", allow_executable = true } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/numpy-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
