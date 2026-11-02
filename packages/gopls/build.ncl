let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.24.0" in
{
  name = "gopls",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golang/tools/archive/refs/tags/gopls/v%{version}.tar.gz",
      sha256 = "5ecc22f581cafe4039873e2f28e0d045efecfb0dfc6ea51ee1345daa694cb6a9",
      extract = true,
      strip_prefix = "tools-gopls-v%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    go,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    gopls = { glob = "usr/bin/gopls" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "tools",
      },
    } | Attrs,
} | BuildSpec
