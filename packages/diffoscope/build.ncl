let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
let python = import "../python/build.ncl" in
let libarchive = import "../libarchive/build.ncl" in
let version = "329" in
{
  name = "diffoscope",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffoscope-%{version}.tar.gz",
      sha256 = "940ee30d8d98231f4d4855e36caf96e9eec9ec3d3cb359b744687b369b2b54d9"
    } | Source,
    base,
    toolchain,
    uv,
  ],
  runtime_deps = [
    python,
    # diffoscope imports python's libarchive-c at STARTUP, which dlopens the
    # native libarchive.so — without it every invocation dies with
    # "undefined symbol: archive_version_number" (found by repro-lab's
    # rc-tools, which invokes every tool instead of trusting `command -v`).
    libarchive,
  ],

  cmd = "./build.sh",
  outputs = {
    diffoscope = { glob = "usr/bin/diffoscope*" } | OutputBin,
    site_packages = { glob = "usr/lib/python*/site-packages/**/*" } | OutputData,
  },
  attrs = {
    upstream_version = version,
    license_spdx = "GPL-3.0-only",
  },
} | BuildSpec
