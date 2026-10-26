let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pyproject-metadata = import "../pyproject-metadata/build.ncl" in

let version = "0.22.1" in
{
  name = "meson-python",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/m/meson_python/meson_python-%{version}.tar.gz",
      sha256 = "52c88628b0e5671592dc2306613fb5f6f3615fd24def059b9894f143b7f9a139",
      extract = true,
      strip_prefix = "meson_python-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    ninja,
    meson,
    pyproject-metadata,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/mesonpy/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/meson_python-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mesonbuild",
        repo = "meson-python",
      },
    } | Attrs,
} | BuildSpec
