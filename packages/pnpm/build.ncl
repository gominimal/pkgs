let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
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
    # ONLY the `node` binary from `node-lts` — deliberately NOT npm/npx/node_modules.
    #
    # pnpm needs a node to interpret its `#!/usr/bin/env node` shebang and
    # nothing else, but whatever it names lands in the closure of every package
    # built with pnpm. Depending on a whole node package dragged a SECOND npm
    # into that closure; the sandbox (and a user session) hardlinks closure
    # members first-writer-wins PER FILE, so /usr/lib/node_modules/npm became a
    # blend of two npm versions that cannot load ("Class extends value
    # undefined"). That broke `next` for two days (#665/#670) and webapp's
    # sessions (#751). The subset means pnpm can never contribute an npm tree.
    #
    # `node-lts`, like every other node consumer: one runtime flavor across the
    # catalog means every package ships the same /usr/bin/node, so there is no
    # first-writer race on the interpreter either (#751 review). `node` (Current)
    # stays available as an explicit opt-in for users.
    subsetOf node-lts ["node"],
    coreutils,
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
