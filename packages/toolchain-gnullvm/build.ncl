let { BuildSpec, .. } = import "minimal.ncl" in
let llvm = import "../llvm/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "toolchain-gnullvm",
  build_deps = [],
  runtime_deps = [
    llvm,
    toolchain,
  ],
  cmd = "",
  outputs = {},
} | BuildSpec
