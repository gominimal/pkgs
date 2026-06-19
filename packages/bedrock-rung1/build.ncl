let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "bedrock-rung1",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
  ],
  cmd = "build.sh",
  outputs = {
    rung1 = { glob = "usr/share/bedrock/rung1" } | OutputData,
  },
} | BuildSpec
