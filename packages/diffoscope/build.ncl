let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
let python = import "../python/build.ncl" in
let libarchive = import "../libarchive/build.ncl" in
let version = "327" in
{
  name = "diffoscope",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffoscope-%{version}.tar.gz",
      sha256 = "b5a398de17b180637cf091ba5c3c9fecde9dc8f5c2c80204ff8dd78e1b9d5358"
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
