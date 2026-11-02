let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# pi is the Pi coding agent (pi.dev), published to npm as
# @earendil-works/pi-coding-agent. It is installed from the sha256-pinned
# registry tarball (the Source below) rather than built from the GitHub
# monorepo, whose build needs the tsgo native TS compiler and a multi-package
# workspace, neither of which is warranted for an npm artifact. The tarball
# ships an npm-shrinkwrap.json, so installing it locks the transitive
# dependency tree and keeps the build reproducible. The `#!/usr/bin/env node`
# shebang of the installed bin is served by coreutils(env) + node.
let version = "1.4.0" in
{
  name = "pi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-%{version}.tgz",
      sha256 = "d155c16ef6fa00960fbf58b2911536e80b05f33700e0b14fbd08967ede0c7428",
    } | Source,
    base,
    node-lts,
  ],
  runtime_deps = [
    coreutils,
    subsetOf node-lts ["node"],
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
    pi = { glob = "usr/bin/pi" } | OutputBin,
    libexec = { glob = "usr/libexec/pi/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "earendil-works",
        repo = "pi",
      },
    } | Attrs,
} | BuildSpec
