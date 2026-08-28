let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let python = import "../python/build.ncl" in

let version = "2.9.5" in
{
  name = "deno",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-x86_64-unknown-linux-gnu.zip",
          sha256 = "8b010a3b1a4a0188a67cdb8a7a27348b2a501af78aec7fc74f2ace167368d530",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/denoland/deno/releases/download/v%{version}/deno-aarch64-unknown-linux-gnu.zip",
          sha256 = "6b7cae3a8fc4385a59dea3146fcb8bad7fea4230e0ad36a8c692afacbc254be0",
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
    libexec = { glob = "usr/libexec/deno/**", allow_executable = true } | OutputData,
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
    # The raw ELF, not the /usr/bin wrapper: standaloneTest runs with no shell
    # in the sandbox, so a #!/bin/sh wrapper would ENOENT there.
    smoketest = standaloneTest "/usr/libexec/deno/deno --version",

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "deno eval 'console.log(1+1)' | grep -q '^2$'"],
        ],
      } | Test,
    global_install_default =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The wrapper must default DENO_INSTALL_ROOT so `deno install -g`
          # bins land in ~/.local/bin, on the session PATH
          # (gominimal/inbox#584).
          ["/bin/bash", "-c", "deno eval \"console.log(Deno.env.get('DENO_INSTALL_ROOT'))\" | grep -q '/.local$'"],
        ],
      } | Test,
  },
} | BuildSpec
