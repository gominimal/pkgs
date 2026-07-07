let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.10.2" in
{
  name = "meson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mesonbuild/meson/%{version}.tar.gz",
      sha256 = "4f3c6fe1d163fb6d5b52094035fc29d14cf4a254c3ac29544ba0a3d5a739c7ba",
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
