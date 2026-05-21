let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let pyproject-hooks = import "../pyproject-hooks/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in

let version = "1.3.12" in
{
  name = "py-mako",
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/source/m/mako/mako-%{version}.tar.gz",
      sha256 = "9f778e93289bd410bb35daadeb4fc66d95a746f0b75777b942088b7fd7af550a",
      extract = true,
      strip_prefix = "mako-%{version}",
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
    pyproject-hooks,
    py-packaging,
  ],

  cmds = [
    "pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir ./",
    "pip3 install --no-index --find-links dist --no-user --root /build/output Mako",
  ],

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/mako/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/Mako-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "sqlalchemy",
        repo = "mako",
      },
    } | Attrs,
} | BuildSpec
