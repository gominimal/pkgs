let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.10.0" in
{
  name = "meson",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/meson-%{version}.tar.gz",
      sha256 = "8071860c1f46a75ea34801490fd1c445c9d75147a65508cd3a10366a7006cc1c",
      extract = true,
      strip_prefix = "meson-%{version}",
    } | Source,
    base,
    setuptools,
    toolchain,
  ],
  runtime_deps = [python],

  cmd = "./build.sh",
  outputs = {
    meson = { glob = "usr/bin/meson" } | OutputLib,
    site_packages = { glob = "usr/lib/python3.13/site-packages/**/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "meson",
    } | Attrs,
} | BuildSpec
