# Imported from npm `yarn` by `pkgmgr import npm` (node build).
# TODO: REVIEWER — installs `yarn` from npm; add any peer packages the
# tool needs (cf. typescript-language-server pulling `typescript`).
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.22.22" in
{
  name = "yarn",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    base,
    node-lts,
  ],
  runtime_deps = [coreutils, subsetOf node-lts ["node"]],
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
    yarn = { glob = "usr/bin/yarn" } | OutputBin,
    yarnpkg = { glob = "usr/bin/yarnpkg" } | OutputBin,
    libexec = { glob = "usr/libexec/yarn/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
    } | Attrs,
} | BuildSpec
