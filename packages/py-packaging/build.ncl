let { Attrs, BuildSpec, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "26.4" in
{
  name = "py-packaging",
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/source/p/packaging/packaging-%{version}.tar.gz",
      sha256 = "c4b671c41ddb9bf26e543c37723610d28fb6bf7affc4da17cf048d419d2c062a",
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

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [python],
        cmds = [
          ["/usr/bin/python3", "-c", "from packaging.version import Version; from packaging.requirements import Requirement; assert Version('1.10') > Version('1.9'); print(Requirement('x>=1; python_version>\"3\"'))"],
        ],
      } | Test,
  },
} | BuildSpec
