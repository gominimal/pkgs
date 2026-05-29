let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in

let version = "0.44.1" in
{
  name = "gemini-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    node,
  ],
  runtime_deps = [
    base,
    node,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/gemini" } | OutputBin,
    libexec = { glob = "usr/lib/node_modules/**", allow_executable = true } | OutputData,
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/gemini --version",

    help =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "gemini --help | grep -qi 'gemini'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "google-gemini",
        repo = "gemini-cli",
      },
      env_dir_mappings = [{ read_only = false, path = "~/.gemini", class = 'State }],
    } | Attrs,
} | BuildSpec
