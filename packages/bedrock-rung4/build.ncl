let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bedrock-rung3 = import "../bedrock-rung3/build.ncl" in
{
  name = "bedrock-rung4",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
    bedrock-rung3,
  ],
  cmd = "build.sh",
  outputs = {
    rung4 = { glob = "usr/share/bedrock/rung4" } | OutputData,
  },
} | BuildSpec
