let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let python = import "../python/build.ncl" in

let version = "2.8.1" in
{
  name = "deno",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-x86_64-unknown-linux-gnu.zip",
          sha256 = "2d7bb6195226ac832e0bf7109a115f0af65ee69ac797a4bbde5b27a06cc242d9",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-aarch64-unknown-linux-gnu.zip",
          sha256 = "67e9df91870fd0af700df924173e3009ea7ff6956e2c3c3bb86065d6070d0fd6",
        } | Source,
    } target,
    base,
    python,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    deno = { glob = "usr/bin/deno" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
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
    smoketest = standaloneTest "/usr/bin/deno --version",

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
