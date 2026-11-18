let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# gotpm, the command-line tool of google/go-tpm-tools. The res-servers run
# `gotpm attest --key gceAK` to quote a build's nonce with the Shielded VM's
# vTPM for the Package Build Log (gominimal/build-servers#554, #353). Built
# without cgo, so the one binary runs on the res-server host as it is.
let version = "0.4.11" in
{
  name = "gotpm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/go-tpm-tools/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "050823ea0aa7bcc14a31f090ffb79bbb9ec5d96fadbb0094e63e75636b67fbe9",
      extract = true,
    } | Source,
    base,
    go,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    gotpm = { glob = "usr/bin/gotpm" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "google",
        repo = "go-tpm-tools",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/gotpm --help",
  },
} | BuildSpec
