let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

let version = "1.3.12" in
{
  name = "py-mako",
  # Mako's sdist requires setuptools as a build-backend (declared in
  # pyproject.toml: `build-backend = 'setuptools.build_meta'`). Python
  # 3.14 no longer bundles setuptools, and `pip3 wheel
  # --no-build-isolation` consults the sandbox's site-packages —
  # setuptools isn't there → BackendUnavailable.
  #
  # Pre-built `py3-none-any.whl` is pure Python and side-steps the
  # build entirely. pip just unzips it. sha-pinned, hermetic.
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/bc/b1/a0ec7a5a9db730a08daef1fdfb8090435b82465abbf758a596f0ea88727e/mako-%{version}-py3-none-any.whl",
      sha256 = "8f61569480282dbf557145ce441e4ba888be453c30989f879f0d652e39f53ea9",
      extract = false,
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
  ],

  cmds = [
    "pip3 install --no-index --no-deps --no-user --root /build/output ./mako-%{version}-py3-none-any.whl",
  ],

  # Wheel layout (verified via unzip -l):
  #   mako/                          # main module
  #   Mako-1.3.12.dist-info/         # WHEEL metadata (canonical case)
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
