# Imported from Wolfi `mkcert` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "1.4.4" in
{
  name = "mkcert",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/FiloSottile/mkcert/v%{version}.tar.gz",
      sha256 = "32bd5519581bf0b03f53e5b22721692b99f39ab5b161dc27532c51eafa512ca9",
      extract = true,
      strip_prefix = "mkcert-%{version}",
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
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    mkcert = { glob = "usr/bin/mkcert" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "FiloSottile", repo = "mkcert" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "mkcert --version"],
          ["/bin/bash", "-c", "mkcert --help"],
        ],
      } | Test,
  },
} | BuildSpec
