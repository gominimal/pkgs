let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in

let node-lts = import "../node-lts/build.ncl" in

let version = "11.19.0" in
{
  name = "pnpm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-%{version}.tgz",
      sha256 = "b9e49603540d04107b98e93917a30e6114970d403c23e40309a44ea9c2bca7fd"
    } | Source,
    base,
    tar,
  ],
  runtime_deps = [
    node-lts,
    coreutils, # pnpm is a sheband script that invokes node like `#!/usr/bin/env node`
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
    pnpm = { glob = "usr/bin/pnpm" } | OutputBin,
    pnpx = { glob = "usr/bin/pnpx" } | OutputBin,

    libexec = { glob = "usr/libexec/pnpm/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pnpm",
        repo = "pnpm",
      },
    } | Attrs,
} | BuildSpec
