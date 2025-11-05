let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "resolver-quad8",
  inputs = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
  ],
  cmd = "build.sh",
  outputs = {
    resolvconf = { glob = "etc/resolv.conf" } | OutputData,
  },
} | BuildSpec
