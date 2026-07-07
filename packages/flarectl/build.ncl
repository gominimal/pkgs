let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# flarectl lives in cmd/flarectl of cloudflare/cloudflare-go. It only shipped in
# the legacy hand-written v0.x SDK line; the auto-generated v2+ rewrite dropped
# cmd/flarectl entirely, so v0.117.0 is the last (and canonical) release carrying it.
let version = "0.117.0" in
{
  name = "flarectl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloudflare/cloudflare-go/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ae76bd5a05eb9f4f8971904377e9570c80a526d670b484d9a31ccd69638d256e",
      extract = true,
      strip_prefix = "cloudflare-go-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    flarectl = { glob = "usr/bin/flarectl" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cloudflare",
        repo = "cloudflare-go",
      },
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/flarectl --version",
  },
} | BuildSpec
