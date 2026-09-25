let { Attrs, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in

# A probe for the Package Build Log (build-servers#353): every kind of
# signal the log claims to capture, deliberately, so the statement can be
# checked against a known script. Not for the registry.
{
  name = "buildlog-probe",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    curl,
  ],
  cmd = "./build.sh",
  outputs = {
    probe = { glob = "usr/share/buildlog-probe/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = "1",
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
