# Bootstrapped from https://github.com/jarun/ddgr by `pkgmgr bootstrap`
# (python), then finalized: outputs read from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let setuptools = import "../setuptools/build.ncl" in
let version = "2.2" in
{
  name = "ddgr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jarun/ddgr/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "a858e0477ea339b64ae0427743ebe798a577c4d942737d8b3460bce52ac52524",
      extract = true,
      strip_prefix = "ddgr-%{version}",
    } | Source,
    base,
    setuptools,
  ],
  cmd = "./build.sh",
  outputs = {
    ddgr = { glob = "usr/bin/ddgr" } | OutputBin,
    # ddgr ships a single top-level module (setup.py `py_modules=['ddgr']`).
    python_site_package = { glob = "usr/lib/python*/site-packages/ddgr.py" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/ddgr-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [
    python,
  ],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "jarun", repo = "ddgr" },
      license_spdx = "GPL-3.0-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "ddgr --version"],
        ],
      } | Test,
  },
} | BuildSpec
