let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pyproject-metadata = import "../pyproject-metadata/build.ncl" in

let version = "0.20.0" in
{
  name = "meson-python",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/m/meson_python/meson_python-%{version}.tar.gz",
      sha256 = "6d9726ae6cd37e22f210c74b364b30180a68c20442e97ff09f3c566a414af738",
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
