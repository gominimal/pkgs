let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

# NOT FOR MERGE. A positive control for the build hosts' egress policy
# (build-servers#412): the build tries the destinations that policy closes to a
# build sandbox and fails if any of them answers. See probe.py.
{
  name = "egress-canary",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "probe.py" } | Local,
    base,
    python,
  ],
  cmd = "./build.sh",

  outputs = {
    result = { glob = "usr/share/egress-canary/*" } | OutputData,
  },

  attrs =
    {
      license_spdx = "Apache-2.0",
    } | Attrs,

  tests = {
    result_present =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/sh", "-c", "test -s /usr/share/egress-canary/result"]],
      } | Test,
  },
} | BuildSpec
