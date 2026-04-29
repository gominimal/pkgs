let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "1.64.0" in
let arch =
  match {
    { arch = 'Amd64, .. } => "x86_64",
    { arch = 'Arm64, .. } => "aarch64",
  } target
in
{
  name = "dotenvx",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    curl,
    tar,
  ],
  runtime_deps = [],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
    include arch,
  },

  outputs = {
    dotenvx = { glob = "usr/bin/dotenvx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "dotenvx",
        repo = "dotenvx",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/dotenvx --version",
    run =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'HELLO=World' > .env"],
          ["/bin/bash", "-c", "dotenvx run -- /bin/bash -c 'echo $HELLO' | grep -q '^World$'"],
        ],
      } | Test,
  },
} | BuildSpec
