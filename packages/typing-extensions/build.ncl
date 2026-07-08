# Imported from Wolfi `typing-extensions` by `pkgmgr import-wolfi` (python build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in
let python = import "../python/build.ncl" in
let version = "4.16.0" in
{
  name = "typing-extensions",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/python/typing_extensions/%{version}.tar.gz",
      sha256 = "4d569f4d4bcd3d26345e0d92cfd14ce1f1302cac2f62a5a7e337c06fb0fdc1ea",
      extract = true,
      strip_prefix = "typing_extensions-%{version}",
    } | Source,
    base,
    flit-core,
  ],
  cmd = "./build.sh",
  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/typing_extensions.py" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/typing_extensions-*.dist-info/**" } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "python", repo = "typing_extensions" },
      license_spdx = "PSF-2.0",
    } | Attrs,
} | BuildSpec
