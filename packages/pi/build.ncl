let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node = import "../node/build.ncl" in

# pi is the Pi coding agent (pi.dev), published to npm as
# @earendil-works/pi-coding-agent. Like the other open-source npm CLI packages
# here (typescript-language-server, bash-language-server), it is installed from
# the registry by name@version into a package-private prefix rather than built
# from the GitHub monorepo (whose build needs the tsgo native TS compiler and a
# multi-package workspace, neither of which is warranted for an npm artifact).
# The `#!/usr/bin/env node` shebang of the installed bin is served by
# coreutils(env) + node.
let version = "0.84.2" in
{
  name = "pi",
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
