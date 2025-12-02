let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in

let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.2.1" in
{
  name = "cython",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cython/cython/releases/download/%{version}/cython-%{version}.tar.gz",
      sha256 = "2be1e4d0cbdf7f4cd4d9b8284a034e1989b59fd060f6bd4d24bf3729394d2ed8",
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
    bins = { glob = "usr/bin/**" } | OutputBin,

    python_site_package = { glob = "usr/lib/python3.13/site-packages/{cython.py,Cython/**}" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/cython-*.dist-info/**" } | OutputData,

    python_site_other = { glob = "usr/lib/python3.13/site-packages/{pyximport,__pycache__}/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
