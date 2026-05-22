let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in

let version = "3.0.2" in
{
  name = "py-markupsafe",
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/source/m/markupsafe/markupsafe-%{version}.tar.gz",
      sha256 = "ee55d3edf80167e48ea11a923c7386f4669df67d7994554387f84e7d8b0a2bf0",
      extract = true,
      strip_prefix = "markupsafe-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    pyproject-hooks,
  ],

  cmds = [
    "pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir ./",
    "pip3 install --no-index --find-links dist --no-user --root /build/output MarkupSafe",
  ],

  # PEP 427 normalizes wheel filenames + dist-info dir names to
  # lowercase, regardless of the canonical package name. Always use
  # the lowercase form for the glob.
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/markupsafe/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/markupsafe-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
