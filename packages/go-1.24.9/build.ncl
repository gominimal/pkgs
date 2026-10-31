let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc-bedrock-2-42-sysroot = import "../glibc-bedrock-2.42-sysroot/build.ncl" in # the sysroot only (see that package)
let glibc = import "../glibc/build.ncl" in
# go-1.24.9: the bootstrap for `go`, from gen-6 of gominimal/bootstrap: the top of the Go ladder,
# go-1.4 -> 1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9 on amd64 and gccgo-15.2.0 -> go-1.17.13 -> ...
# -> 1.24.9 on arm64 (Go 1.5 added arm64, so the C-hosted go-1.4 cannot start that chain), every
# rung built on the hex0-rooted toolchain and reproduced byte for byte on two independent
# machines before publishing (generations/gen-6/manifest.json). Ships the whole GOROOT at
# /usr/lib/go-1.24.9; nothing lands on /usr/bin.
let is_arm = target.arch == 'Arm64 in
let version = "1.24.9" in
{
  name = "go-1.24.9",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-6/sha256/6ca7638ab8cde5ea64255f1adf2e7ddf0e166c0c6a3a7afccb86392f1650a572/go-1.24.9-1.24.9-x86_64.tar.zst",
          sha256 = "6ca7638ab8cde5ea64255f1adf2e7ddf0e166c0c6a3a7afccb86392f1650a572",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-6/sha256/1a4250067fadc06ef128c00aa5ad62e22d0834a0dbedfb849acc7b5bdbefdf1e/go-1.24.9-1.24.9-aarch64.tar.zst",
          sha256 = "1a4250067fadc06ef128c00aa5ad62e22d0834a0dbedfb849acc7b5bdbefdf1e",
          extract = true,
        } | Source,
    } target,
  ],
  runtime_deps = if is_arm then [glibc] else [glibc-bedrock-2-42-sysroot],
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
