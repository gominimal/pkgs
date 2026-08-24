let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node = import "../node/build.ncl" in

let version = "5.3.0" in
{
  name = "typescript-language-server",
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
    typescript-language-server = { glob = "usr/bin/typescript-language-server" } | OutputBin,
    tsserver = { glob = "usr/bin/tsserver" } | OutputBin,
    tsc = { glob = "usr/bin/tsc" } | OutputBin,
    libexec = { glob = "usr/libexec/typescript-language-server/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
