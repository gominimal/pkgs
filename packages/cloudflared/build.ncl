let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026.10.0" in
{
  name = "cloudflared",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloudflare/cloudflared/archive/refs/tags/%{version}.tar.gz",
      sha256 = "60203c146da07015fda8b1c583939828913f1310d63716666124a89c0f86bd8c",
      extract = true,
      strip_prefix = "cloudflared-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  # Go modules are fetched at build time (verified against go.sum): upstream removed
  # vendor/ in TUN-10829 (2026-09-02), first shipped in 2026.9.x.
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
    cloudflared = { glob = "usr/bin/cloudflared" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "cloudflared",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cloudflare",
        repo = "cloudflared",
      },
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/cloudflared --version",
  },
} | BuildSpec
