let { Attrs, BuildSpec, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let bash = import "../bash/build.ncl" in # bin/ghc is a /bin/sh wrapper
let llvm = import "../llvm/build.ncl" in # arm64: settings name ld.lld as the linker and object merger
# ghc-9.6.7: the boot compiler for `ghc`, from gen-15 of gominimal/bootstrap: the top of the
# source-only GHC ladder, microhs-0.16 (C, gcc) -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 -> 7.0.4
# -> 7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7, every rung built on the
# hex0-rooted toolchain and this one reproduced byte for byte on two independent machines before
# publishing (generations/gen-15/manifest.json). Installs the whole compiler at /usr/lib/ghc-9.6.7;
# nothing lands on /usr/bin. Its `settings` name the shipped C compiler wrapper
# /usr/lib/ghc-9.6.7/bin/ghc-cc, which runs the gcc on PATH (amd64: linking with the
# /usr/lib/ld-linux-x86-64.so.2 loader its own binaries load through).
let is_arm = target.arch == 'Arm64 in
let version = "9.6.7" in
{
  name = "ghc-9.6.7",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-15/sha256/fd4510bb45d9e22452498272c5f181349661b0a9b02a4fbec6985eb0acaddd3c/ghc-9.6.7-9.6.7-x86_64.tar.zst",
          sha256 = "fd4510bb45d9e22452498272c5f181349661b0a9b02a4fbec6985eb0acaddd3c",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-15/sha256/1fbf165682ba3549d60b589d6040853df67666f3243834ecfe8d6bbee652fa5f/ghc-9.6.7-9.6.7-aarch64.tar.zst",
          sha256 = "1fbf165682ba3549d60b589d6040853df67666f3243834ecfe8d6bbee652fa5f",
          extract = true,
        } | Source,
    } target,
  ],
  # the compiler links libgmp and libncursesw from /usr/lib (libffi is bundled); arm64 also needs lld
  runtime_deps = (if is_arm then [glibc, llvm] else [glibc]) @ [gmp, ncurses],
  # the binary runs from its own runtime closure, outside any build sandbox
  tests = {
    ghc_version =
      {
        class = 'Standalone,
        test_deps = [bash],
        cmds = [["/bin/sh", "-c", "v=$(/usr/lib/ghc-9.6.7/bin/ghc --numeric-version) && [ \"$v\" = 9.6.7 ]"]],
      } | Test,
  },
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
