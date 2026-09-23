# Imported from npm `typescript` by `pkgmgr import npm` (node build).
# TODO: REVIEWER — installs `typescript` from npm; add any peer packages the
# tool needs (cf. typescript-language-server pulling `typescript`).
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "7.0.2" in
{
  name = "typescript",
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
    tsc = { glob = "usr/bin/tsc" } | OutputBin,
    libexec = { glob = "usr/libexec/typescript/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
