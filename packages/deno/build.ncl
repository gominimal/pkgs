let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let python = import "../python/build.ncl" in

let version = "2.9.4" in
{
  name = "deno",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-x86_64-unknown-linux-gnu.zip",
          sha256 = "c24f955d9fbfe0ea5ae2b501c8e71ae76e31e4c9782390a54a284b3364fda725",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-aarch64-unknown-linux-gnu.zip",
          sha256 = "111da5c05c240cfdc4340f234a0e3539d39dbcb6755221f19dcd60bacc8be5aa",
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
