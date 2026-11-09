let { Attrs, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "resolver-quad8",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
  ],
  cmd = "build.sh",
  outputs = {
    resolvconf = { glob = "etc/resolv.conf" } | OutputData,
  },
  # Authored in this repository, so Apache-2.0 like every recipe here
  # (LICENSING.md section 1).
  attrs = { license_spdx = "Apache-2.0" } | Attrs,
} | BuildSpec
