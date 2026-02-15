let { standaloneTest, BuildSpec, Local, Needs, OutputBin, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

{
  name = "minimal-sshd",
  inputs = [
    { file = "build.sh" } | Local,
    { file = "main.go" } | Local,
    { file = "go.mod" } | Local,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    minimal-sshd = { glob = "usr/bin/minimal-sshd" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/minimal-sshd --help",
  },
} | BuildSpec
