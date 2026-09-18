# Imported from npm `prettier` by `pkgmgr import npm` (node build).
# TODO: REVIEWER — installs `prettier` from npm; add any peer packages the
# tool needs (cf. typescript-language-server pulling `typescript`).
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "3.9.8" in
{
  name = "prettier",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    base,
    node,
  ],
  runtime_deps = [coreutils, node],
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
    prettier = { glob = "usr/bin/prettier" } | OutputBin,
    libexec = { glob = "usr/libexec/prettier/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
