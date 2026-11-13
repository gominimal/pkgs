let { Attrs, BuildSpec, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
# go-1.24.9: the bootstrap for `go`, from gen-13 of gominimal/bootstrap: the top of the Go ladder,
# go-1.4 -> 1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9 on amd64 and gccgo-15.2.0 -> go-1.17.13 -> ...
# -> 1.24.9 on arm64 (Go 1.5 added arm64, so the C-hosted go-1.4 cannot start that chain), every
# rung built on the hex0-rooted toolchain and reproduced byte for byte on two independent
# machines before publishing (generations/gen-13/manifest.json). Ships the whole GOROOT at
# /usr/lib/go-1.24.9; nothing lands on /usr/bin.
let version = "1.24.9" in
{
  name = "go-1.24.9",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-13/sha256/aa68542123f37cdf6b9e24796dec360d003c6693f0289f55daba5736ceae12ca/go-1.24.9-1.24.9-x86_64.tar.zst",
          sha256 = "aa68542123f37cdf6b9e24796dec360d003c6693f0289f55daba5736ceae12ca",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-13/sha256/1a4250067fadc06ef128c00aa5ad62e22d0834a0dbedfb849acc7b5bdbefdf1e/go-1.24.9-1.24.9-aarch64.tar.zst",
          sha256 = "1a4250067fadc06ef128c00aa5ad62e22d0834a0dbedfb849acc7b5bdbefdf1e",
          extract = true,
        } | Source,
    } target,
  ],
  runtime_deps = [glibc],
  # the binary runs from its own runtime closure, outside any build sandbox
  tests = {
    go_version =
      {
        class = 'Standalone,
        cmds = [["/usr/lib/go-1.24.9/bin/go", "version"]],
      } | Test,
  },
  outputs = {
    goroot = { glob = "usr/lib/go-1.24.9/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/go-1.24.9/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "go",
      },
    } | Attrs,
} | BuildSpec
