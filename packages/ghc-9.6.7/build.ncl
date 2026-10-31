let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc-bedrock-2-42-sysroot = import "../glibc-bedrock-2.42-sysroot/build.ncl" in # the sysroot only (see that package)
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
# ghc-9.6.7: the boot compiler for `ghc`, from gen-7 of gominimal/bootstrap: the top of the
# source-only GHC ladder, microhs-0.16 (C, gcc) -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 -> 7.0.4
# -> 7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7, every rung built on the
# hex0-rooted toolchain and this one reproduced byte for byte on two independent machines before
# publishing (generations/gen-7/manifest.json). Installs the whole compiler at /usr/lib/ghc-9.6.7;
# nothing lands on /usr/bin. Its `settings` name the shipped C compiler wrapper
# /usr/lib/ghc-9.6.7/bin/ghc-cc, which runs the gcc on PATH (amd64: against the bedrock sysroot).
let is_arm = target.arch == 'Arm64 in
let version = "9.6.7" in
{
  name = "ghc-9.6.7",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-7/sha256/9622e9d3fb4526634851289545590cee0326f52a2f66b0b08733d971b6dbd27e/ghc-9.6.7-9.6.7-x86_64.tar.zst",
          sha256 = "9622e9d3fb4526634851289545590cee0326f52a2f66b0b08733d971b6dbd27e",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-7/sha256/ebfdc8c7df002a8160cd7f7f6c0e6739497403ccba6411bba9f1a4b2e495e159/ghc-9.6.7-9.6.7-aarch64.tar.zst",
          sha256 = "ebfdc8c7df002a8160cd7f7f6c0e6739497403ccba6411bba9f1a4b2e495e159",
          extract = true,
        } | Source,
    } target,
  ],
  # the compiler links libgmp and libncursesw from /usr/lib (libffi is bundled); amd64 binaries
  # run on the bedrock sysroot's loader and libc, arm64's on the toolchain glibc
  runtime_deps = (if is_arm then [glibc] else [glibc-bedrock-2-42-sysroot]) @ [gmp, ncurses],
  outputs = {
    ghc = { glob = "usr/lib/ghc-9.6.7/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/ghc-9.6.7/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'Website,
        homepage = "https://www.haskell.org/ghc/",
        downloads_page = "https://downloads.haskell.org/~ghc/9.6.7/",
      },
    } | Attrs,
} | BuildSpec
