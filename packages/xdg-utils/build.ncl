let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# xdg-utils — freedesktop.org desktop-integration scripts (xdg-open and
# friends). Pure POSIX shell, no compiled component.
#
# The agentbox image ships its OWN `container/xdg-open` wrapper over the top of
# this, because inside a container there is no desktop to hand a URL to. This
# package provides the rest of the suite (xdg-mime, xdg-settings, …) that the
# wrapper and various tools expect to exist.
#
# Upstream is GitLab (gitlab.freedesktop.org/xdg/xdg-utils), so `pkgmgr import`
# could not emit it and the source comes from the gs:// staging mirror.
let version = "1.2.1" in

{
  name = "xdg-utils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xdg-utils-%{version}.tar.gz",
      sha256 = "f6b648c064464c2636884c05746e80428110a576f8daacf46ef2e554dcfdae75",
      extract = true,
      strip_prefix = "xdg-utils-v%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    bash,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/xdg-*" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "xdg-utils",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # These are shell scripts, so the meaningful check is that they are
          # present, executable and parse — not that they can reach a desktop.
          ["/bin/bash", "-c", "/bin/xdg-open --version | grep -q xdg-open"],
          ["/bin/bash", "-c", "/bin/bash -n /bin/xdg-mime"],
        ],
      } | Test,
  },
} | BuildSpec
