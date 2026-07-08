# Imported from Wolfi `json-server` by `pkgmgr import-wolfi` (node build),
# with outputs refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "0.17.4" in
{
  name = "json-server",
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
    json-server = { glob = "usr/bin/json-server" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
