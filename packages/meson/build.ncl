let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.11.2" in
{
  name = "meson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mesonbuild/meson/%{version}.tar.gz",
      sha256 = "09cc2faedc61262fc62abf57aa6c47c57a8c0730b950609a0711bbaf587bd133",
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
    meson = { glob = "usr/bin/meson" } | OutputBin,
    site_packages = { glob = "usr/lib/python*/site-packages/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "meson",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mesonbuild",
        repo = "meson",
      },
    } | Attrs,
} | BuildSpec
