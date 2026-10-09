let { Attrs, BuildSpec, Local, OutputBin, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# Modern Yarn (2+, "berry") for projects that pin it in package.json
# (`"packageManager": "yarn@4.x"`), which the classic `yarn` package (1.22)
# refuses to run. These `yarn`/`yarnpkg` commands hand off to Corepack, which
# ships with node-lts and runs exactly the pinned release. Installs the same
# commands as `yarn`, so a session takes one or the other; the ruby/rails
# stacks pick this one when yarn.lock is a Yarn 2+ lockfile.
#
# Needs node-lts specifically: Node 25+ no longer bundles Corepack.
{
  name = "yarn-corepack",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
  ],
  runtime_deps = [
    bash,
    node-lts,
  ],
  cmd = "./build.sh",
  outputs = {
    yarn = { glob = "usr/bin/yarn" } | OutputBin,
    yarnpkg = { glob = "usr/bin/yarnpkg" } | OutputBin,
  },
  attrs =
    {
      # The two wrapper scripts are this repository's own work.
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    # `yarn` reaches Corepack and Corepack honours packageManager: with the
    # network off it must name the pinned release it would have fetched.
    dispatches_to_corepack =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "d=$(mktemp -d) && cd \"$d\" && echo '{\"packageManager\":\"yarn@4.9.9\"}' > package.json && out=$(HOME=$d COREPACK_ENABLE_NETWORK=0 /bin/yarn --version 2>&1); echo \"$out\" | grep -q '4.9.9' || { echo \"$out\" >&2; exit 1; }"],
        ],
      } | Test,
  },
} | BuildSpec
