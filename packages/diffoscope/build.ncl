let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
let python = import "../python/build.ncl" in
let version = "325" in
{
  name = "diffoscope",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffoscope-%{version}.tar.gz",
      sha256 = "d74a2edb0555a9ee306d5362b921f80c144bb941c0a6d61794473d1540d729ad"
    } | Source,
    base,
    toolchain,
    uv,
  ],
  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",
  outputs = {
    diffoscope = { glob = "usr/bin/diffoscope" } | OutputBin,
    site_packages = { glob = "usr/lib/python*/site-packages/**/*" } | OutputData,
  },
  attrs = {
    upstream_version = version,
    license_spdx = "GPL-3.0-only",
  },
} | BuildSpec
