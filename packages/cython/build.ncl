let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in

let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.2.8" in
{
  name = "cython",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cython/cython/releases/download/%{version}/cython-%{version}.tar.gz",
      sha256 = "f4f23a56b25221a06f91817fe8f3114ab8b48a4fac73187dbb64bc2c4a87961f",
      extract = true,
      strip_prefix = "cython-%{version}",
    } | Source,
    base,
    setuptools,
  ],

  runtime_deps = [
    python,
    toolchain,
  ],

  cmd = "./build.sh",

  outputs = {
    cythonize = { glob = "usr/bin/cythonize" } | OutputBin,
    cython = { glob = "usr/bin/cython" } | OutputBin,
    cygdb = { glob = "usr/bin/cygdb" } | OutputBin,

    python_site_package = { glob = "usr/lib/python*/site-packages/{cython.py,Cython/**}", allow_data = true } | OutputLib,
    python_dist_info = { glob = "usr/lib/python*/site-packages/cython-*.dist-info/**" } | OutputData,

    python_site_other = { glob = "usr/lib/python*/site-packages/{pyximport,__pycache__}/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cython",
        repo = "cython",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
