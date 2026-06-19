let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bedrock-rung2 = import "../bedrock-rung2/build.ncl" in
{
  name = "bedrock-rung3",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
    bedrock-rung2,
  ],
  cmd = "build.sh",
  outputs = {
    rung3 = { glob = "usr/share/bedrock/rung3" } | OutputData,
  },
} | BuildSpec
