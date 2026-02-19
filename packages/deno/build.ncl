let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let python = import "../python/build.ncl" in

let version = "2.6.9" in
{
  name = "deno",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-x86_64-unknown-linux-gnu.zip",
      sha256 = "8a677a4b0cea1a25aaecfc70d6c6a288f9ad69af0a92e9e9d513cabaaf3c688f",
    } | Source,
    base,
    python,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    deno = { glob = "usr/bin/deno" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      env_state_wiring = {
        env_var = "DENO_DIR",
        prefix = "deno-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "denoland",
        repo = "deno",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/deno --version",

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "deno eval 'console.log(1+1)' | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
