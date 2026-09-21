let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# tree — recursive directory listing.
#
# Needed by the agentbox image. Upstream lives on GitLab
# (OldManProgrammer/unix-tree), not GitHub, which is why `pkgmgr import wolfi`
# could resolve the recipe but refused to emit: the renderer only handles
# github sources today. Hand-written for that reason.
#
# Sourced from the gs:// staging mirror like every other non-github package
# here — a direct gitlab.com URL is also not reachable from the build sandbox.
let version = "2.3.2" in

{
  name = "tree",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/unix-tree-%{version}.tar.gz",
      sha256 = "513a53cbc42ca1f4ea06af2bab1f5283524a3848266b1d162416f8033afc4985",
      extract = true,
      strip_prefix = "unix-tree-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bin = { glob = "usr/bin/tree" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      repology_project = "tree",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Assert it actually walks a tree, not just that it exits 0.
          ["/bin/bash", "-c", "mkdir -p /tmp/t/a/b && /bin/tree /tmp/t | grep -q b"],
          ["/bin/bash", "-c", "/bin/tree --version | grep -q 2.3.2"],
        ],
      } | Test,
  },
} | BuildSpec
