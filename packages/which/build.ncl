let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# GNU which — resolves a command name against PATH the way the shell would.
#
# Needed by the agentbox image, which calls `which` in build and entrypoint
# scripts. We had no package for it: the fleet has `bandwhich` (an unrelated
# network tool) and nothing else matching, so this is genuinely new rather
# than a rename.
#
# GNU which has no git forge home, which is why `pkgmgr import` could not seed
# it. Sourced from the gs:// staging mirror like every other GNU package here —
# ftp.gnu.org answers 403 from inside the build sandbox, so a direct upstream
# URL builds on a laptop and fails in the box. 2.25 is the current release;
# the bucket already had 2.21 from some earlier pass.
let version = "2.25" in

{
  name = "which",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/which-%{version}.tar.gz",
      sha256 = "1cb83e4f702e60b8211ab5ec4c2afbab1b1dec80209456a7d2faf7584ed225ea",
      extract = true,
      strip_prefix = "which-%{version}",
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
    bin = { glob = "usr/bin/which" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      repology_project = "which",
      source_provenance = {
        category = 'GnuProject,
        name = "which",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Resolve something guaranteed present, and assert the path rather
          # than just a zero exit — `which` returning nothing successfully is
          # the failure this test exists to catch.
          ["/bin/bash", "-c", "/bin/which sh | grep -q /sh"],
        ],
      } | Test,
  },
} | BuildSpec
