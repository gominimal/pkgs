let { BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
let python = import "../python/build.ncl" in
let libarchive = import "../libarchive/build.ncl" in
let file = import "../file/build.ncl" in
let version = "337" in
{
  name = "diffoscope",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffoscope-%{version}.tar.gz",
      sha256 = "ca1c12904e7ef441649c34675de50496d2228a709662864a613844ee207e4dcd"
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
    file,
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

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/usr/bin/bash", "-c", "/usr/bin/diffoscope --version"]],
      } | Test,
  },
} | BuildSpec
