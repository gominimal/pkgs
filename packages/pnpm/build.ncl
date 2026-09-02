let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in

let node-lts = import "../node-lts/build.ncl" in

let version = "11.21.0" in
{
  name = "pnpm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-%{version}.tgz",
      sha256 = "87237d37eadb79dc626a0576eb3a52d23d70422c323ae5e00fc05c91f4323780"
    } | Source,
    base,
    tar,
  ],
  runtime_deps = [
    node-lts,
    coreutils, # pnpm is a sheband script that invokes node like `#!/usr/bin/env node`
    bash, # the /usr/bin wrappers are #!/bin/sh scripts (bash provides bin/sh)
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

  tests = {
    global_bin_dir =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The wrapper must default PNPM_HOME so the derived global bin dir
          # lands under ~/.local rather than an off-PATH location
          # (gominimal/inbox#584). PATH is extended here because the test
          # sandbox's PATH may not carry ~/.local/bin the way sessions do.
          ["/bin/bash", "-c", "PATH=\"$PATH:$HOME/.local/bin\" pnpm bin -g | grep -q '/.local/bin$'"],
        ],
      } | Test,
  },
} | BuildSpec
