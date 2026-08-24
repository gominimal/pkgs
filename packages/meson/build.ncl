let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.12.0" in
{
  name = "meson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mesonbuild/meson/%{version}.tar.gz",
      sha256 = "5ab1c86446d9dfe073f07141088cde545e43f8ddb2f97ebe3f600ab12e77ca1f",
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
