let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "6.0.3" in
{
  name = "py-pyyaml",
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-%{version}.tar.gz",
      sha256 = "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f",
      extract = true,
      strip_prefix = "pyyaml-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    pyproject-hooks,
  ],

  cmds = [
    "pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir ./",
    "pip3 install --no-index --find-links dist --no-user --root /build/output PyYAML",
  ],

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/yaml/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/PyYAML-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "yaml",
        repo = "pyyaml",
      },
    } | Attrs,
} | BuildSpec
