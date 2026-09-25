let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let tar = import "../tar/build.ncl" in

let node-lts = import "../node-lts/build.ncl" in

let version = "12.5.1" in
{
  name = "pnpm",
  build_deps = [
    { file = "build.sh" } | Local,
    # pnpm 12 is a native binary, published per platform as `@pnpm/exe.<os>-<arch>`.
    # The `pnpm` package below is only the wrapper around it; left to itself it
    # DOWNLOADS the binary on first run, so we ship both halves instead (see
    # build.sh): the binary from here, dist/ (bundled node-gyp) from the wrapper.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://registry.npmjs.org/@pnpm/exe.linux-x64/-/exe.linux-x64-%{version}.tgz",
          sha256 = "c980bc463e4b1dcd34ab136c738d987dd21a5590f4b4b82dc2c8ad3e605e2f7f"
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://registry.npmjs.org/@pnpm/exe.linux-arm64/-/exe.linux-arm64-%{version}.tgz",
          sha256 = "d6b8b296256372cdbd02be78b7e19b8387de252abcf920017987660b76c429e8"
        } | Source,
    } target,
    {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-%{version}.tgz",
      sha256 = "3c1439171c1396d7f30892d2444135c9f11de739175058a1503cdf53788f2099"
    } | Source,
    base,
    tar,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    # `pn`/`pnpx`/`pnx` are upstream's `#!/bin/sh` alias scripts (they resolve
    # their symlink with `command -p readlink`), and pnpm runs lifecycle scripts
    # through `sh`.
    bash,
    coreutils,
    # ONLY the `node` binary from `node-lts` — deliberately NOT npm/npx/node_modules.
    #
    # pnpm 12 no longer needs node to run ITSELF (it is native), but a pnpm with
    # no node cannot do its job: package lifecycle scripts, the bundled node-gyp
    # wrapper (dist/node-gyp-bin/node-gyp runs `node .../node-gyp.js`) and
    # `pnpm run`/`exec` of any JS bin all spawn `node`. So pnpm keeps providing
    # the interpreter, as it did in 11.x.
    #
    # Whatever it names lands in the closure of every package built with pnpm.
    # Depending on a whole node package dragged a SECOND npm into that closure;
    # the sandbox (and a user session) hardlinks closure members first-writer-wins
    # PER FILE, so /usr/lib/node_modules/npm became a blend of two npm versions
    # that cannot load ("Class extends value undefined"). That broke `next` for
    # two days (#665/#670) and webapp's sessions (#751). The subset means pnpm
    # can never contribute an npm tree.
    #
    # `node-lts`, like every other node consumer: one runtime flavor across the
    # catalog means every package ships the same /usr/bin/node, so there is no
    # first-writer race on the interpreter either (#751 review). `node` (Current)
    # stays available as an explicit opt-in for users.
    subsetOf node-lts ["node"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    pnpm = { glob = "usr/bin/pnpm" } | OutputBin,
    pn = { glob = "usr/bin/pn" } | OutputBin,
    pnpx = { glob = "usr/bin/pnpx" } | OutputBin,
    pnx = { glob = "usr/bin/pnx" } | OutputBin,

    # The native binary, its alias scripts and dist/ (bundled node-gyp) live
    # together: the binary finds dist/ relative to its own path.
    libexec = { glob = "usr/libexec/pnpm/**", allow_executable = true } | OutputData,
  },

  tests = {
    # The native binary runs, at the pinned version, and never falls back to the
    # wrapper's download path ("Downloading the pnpm <v> binary ..." on stderr).
    cli =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "out=$(pnpm --version 2>&1) && echo \"$out\" && test \"$out\" = '%{version}'"],
          ["/bin/bash", "-c", "out=$(pn --version 2>&1) && test \"$out\" = '%{version}'"],
          ["/bin/bash", "-c", "file -L /usr/bin/pnpm | grep -q ELF"],
          ["/bin/bash", "-c", "! pnpm --version 2>&1 | grep -qi download"],
        ],
      } | Test,
    # A dependency-free install works offline, and a root lifecycle script sees
    # the bundled node-gyp on PATH (dist/ is found beside the binary).
    install =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -e; mkdir -p /tmp/p && cd /tmp/p && printf '%s' '{\"name\":\"t\",\"version\":\"1.0.0\",\"scripts\":{\"postinstall\":\"command -v node-gyp > gyp.txt && node --version > node.txt\"}}' > package.json && pnpm install --offline 2>&1 | tee log.txt; if grep -qi download log.txt; then exit 1; fi; grep -q '/usr/libexec/pnpm/dist/node-gyp-bin/node-gyp' gyp.txt; test -s node.txt"],
        ],
      } | Test,
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
