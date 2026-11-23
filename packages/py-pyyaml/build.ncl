let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in

# YAML parser and emitter. mesa needs it at BUILD time: its format tables are
# YAML, and meson.build refuses to configure without the `yaml` module. mesa's
# build used to fetch it from PyPI, unpinned.
#
# Pure Python: build.sh turns off the optional libyaml extension, which would
# need Cython, a C compiler and libyaml.
let version = "6.0.3" in
{
  name = "py-pyyaml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-%{version}.tar.gz",
      sha256 = "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f",
      extract = true,
      strip_prefix = "pyyaml-%{version}",
    } | Source,
    base,
    # PEP 517 backend; build-only.
    setuptools,
  ],

  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/{yaml,_yaml}/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/{PyYAML,pyyaml}-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "yaml",
        repo = "pyyaml",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["python3", "-c", "import yaml; assert yaml.safe_load('a: [1, 2]') == {'a': [1, 2]}; assert yaml.safe_load(yaml.safe_dump({'k': 'v'})) == {'k': 'v'}; print(yaml.__version__)"],
        ],
      } | Test,
  },
} | BuildSpec
