let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026.6.1" in
{
  name = "cloudflared",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloudflare/cloudflared/archive/refs/tags/%{version}.tar.gz",
      sha256 = "c3619a29cc529a5bc43ba99e1b298483ac0b8d8c412f69575c089a6bd4a7867d",
      extract = true,
      strip_prefix = "cloudflared-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  # No `needs` block: the source tarball vendors all Go modules (vendor/), so the
  # build resolves everything offline via `go build -mod=vendor`.

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
