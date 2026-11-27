let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let py-markupsafe = import "../py-markupsafe/build.ncl" in

# Template library. mesa needs it at BUILD time: its meson.build refuses to
# configure without the `mako` module, which generates C sources from
# templates. mesa's build used to fetch it from PyPI, unpinned.
let version = "1.4.3" in
{
  name = "py-mako",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/m/mako/mako-%{version}.tar.gz",
      sha256 = "cd6537fe88d5fec315c55c2f8529bc4ce7a9a352ad7db3eeaa6a66e2dd4ec37a",
      extract = true,
      strip_prefix = "mako-%{version}",
    } | Source,
    base,
    # PEP 517 backend; build-only.
    setuptools,
  ],

  runtime_deps = [
    python,
    py-markupsafe,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/mako/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/mako-*.dist-info/**" } | OutputData,
    mako_render = { glob = "usr/bin/mako-render" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sqlalchemy",
        repo = "mako",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["python3", "-c", "from mako.template import Template; assert Template('${a} + ${b}').render(a=1, b=2) == '1 + 2'; import mako; print(mako.__version__)"],
        ],
      } | Test,
  },
} | BuildSpec
