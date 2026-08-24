# Imported from Wolfi `serve` by `pkgmgr import-wolfi` (node build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "14.2.6" in
{
  name = "serve",
  build_deps = [
    { file = "build.sh" } | Local,
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
    serve = { glob = "usr/bin/serve" } | OutputBin,
    libexec = { glob = "usr/libexec/serve/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
