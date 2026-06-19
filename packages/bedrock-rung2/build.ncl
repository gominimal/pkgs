let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bedrock-rung1 = import "../bedrock-rung1/build.ncl" in
{
  name = "bedrock-rung2",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
    bedrock-rung1,
  ],
  cmd = "build.sh",
  outputs = {
    rung2 = { glob = "usr/share/bedrock/rung2" } | OutputData,
  },
} | BuildSpec
