let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in

let node = import "../node/build.ncl" in

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
    # `node`, NOT `node-lts`. pnpm only needs *a* node for its
    # `#!/usr/bin/env node` shebang, but whichever one it names lands in the
    # closure of every package that builds with pnpm. `next` and
    # `agent-browser` both declare `node` themselves, so naming `node-lts` here
    # put TWO npm installs in one sandbox — and since the sandbox hardlinks
    # closure members first-writer-wins PER FILE, the resulting
    # /usr/lib/node_modules/npm was a blend of both versions:
    # minipass-flush/index.js from npm 11.17.0 (named `{ Minipass }` import)
    # beside a nested minipass@3.3.6 from npm 11.11.1 (default export only).
    # That tree has never existed upstream and cannot load — every
    # `npm install` died, which broke `next` for two days. See pkgs#665/#670.
    # ONLY the `node` binary — deliberately NOT npm/npx/node_modules.
    #
    # pnpm needs a node to interpret its `#!/usr/bin/env node` shebang and
    # nothing else. Depending on the whole package dragged a SECOND npm into
    # the closure of everything built with pnpm, and since the sandbox
    # hardlinks closure members first-writer-wins PER FILE, the resulting
    # /usr/lib/node_modules/npm was a blend of two npm versions that cannot
    # load (see the commit message and pkgs#665). Taking the subset means pnpm
    # can never contribute an npm tree at all, so that class is closed even if
    # a consumer later picks a different node.
    subsetOf node ["node"],
    coreutils,
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
