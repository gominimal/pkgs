let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "26.3" in
{
  name = "py-packaging",
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/source/p/packaging/packaging-%{version}.tar.gz",
      sha256 = "94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79",
      extract = true,
      strip_prefix = "packaging-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    pyproject-hooks,
  ],

  cmds = [
    "pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir ./",
    "pip3 install --no-index --find-links dist --no-user --root /build/output packaging",
  ],

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/packaging/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/packaging-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 OR BSD-2-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pypa",
        repo = "packaging",
      },
    } | Attrs,
} | BuildSpec
