let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node = import "../node/build.ncl" in

# pi is the Pi coding agent (pi.dev), published to npm as
# @earendil-works/pi-coding-agent. It is installed from the sha256-pinned
# registry tarball (the Source below) rather than built from the GitHub
# monorepo, whose build needs the tsgo native TS compiler and a multi-package
# workspace, neither of which is warranted for an npm artifact. The tarball
# ships an npm-shrinkwrap.json, so installing it locks the transitive
# dependency tree and keeps the build reproducible. The `#!/usr/bin/env node`
# shebang of the installed bin is served by coreutils(env) + node.
let version = "0.84.2" in
{
  name = "pi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-%{version}.tgz",
      sha256 = "95b899cd7b1a0c1f0174c7bf33ab427435e3553a7d1f4756661aa9c7f1a68ffa",
    } | Source,
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
