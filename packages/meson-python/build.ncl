let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pyproject-metadata = import "../pyproject-metadata/build.ncl" in

let version = "0.18.0" in
{
  name = "meson-python",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/m/meson_python/meson_python-%{version}.tar.gz",
      sha256 = "c56a99ec9df669a40662fe46960321af6e4b14106c14db228709c1628e23848d",
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
    python_site_package = { glob = "usr/lib/python3.13/site-packages/mesonpy/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python3.13/site-packages/meson_python-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "mesonbuild",
        repo = "meson-python",
      },
    } | Attrs,
} | BuildSpec
