let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node = import "../node/build.ncl" in

let version = "4.108.0" in
{
  name = "wrangler",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    node,
  ],
  runtime_deps = [
    coreutils,
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
    wrangler = { glob = "usr/bin/wrangler" } | OutputBin,
    wrangler2 = { glob = "usr/bin/wrangler2" } | OutputBin,
    cf-wrangler = { glob = "usr/bin/cf-wrangler" } | OutputBin,
    libexec = { glob = "usr/lib/node_modules/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cloudflare",
        repo = "workers-sdk",
      },
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/wrangler --version",
  },
} | BuildSpec
