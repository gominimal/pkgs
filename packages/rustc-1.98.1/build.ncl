let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# rustc-1.98.1: builds rustc 1.98.1 from the upstream -src tarball with the rustc-1.97.1 package as
# x.py's stage0, strictly offline, installed to /usr/lib/rustc-1.98.1 (bin/ + lib/ only).
# packages/rust consumes this rung as its stage0.
# Same recipe as every rustc-1.9x rung: only version, stage0_version, the stage0 import and the
# Source sha256 differ in this file; VERSION and STAGE0_VERSION differ in build.sh.  See README.md.
let rustc-1-97-1 = import "../rustc-1.97.1/build.ncl" in # the stage0 (amd64)
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let curl = import "../curl/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libssh2 = import "../libssh2/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# pkgmgr: bootstrap_rung = "rust"
let version = "1.98.1" in
let stage0_version = "1.97.1" in
# stage0 by arch.  amd64: the rustc-1.97.1 rung.  arm64: the rung chain is amd64-only, so take the
# same sha-pinned rustc-1.97.1 bedrock tarball packages/rust 1.98.1 used; build.sh points at its
# extracted ./rustc-1.97.1-aarch64.  This rung builds on BOTH arches so packages/rust 1.99 gets a
# 1.98.1 stage0 from the builder on arm64 too, with no new hand-built prebuilt.
let stage0 =
  match {
    { arch = 'Amd64, .. } => rustc-1-97-1,
    { arch = 'Arm64, .. } =>
      {
        url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/de0724a4bf882c5f4641dc6edd6284ee0fa565a405d4ea264a4f305e3bfe5e6e/rustc-1.97.1-aarch64.tar.zst",
        sha256 = "de0724a4bf882c5f4641dc6edd6284ee0fa565a405d4ea264a4f305e3bfe5e6e",
        extract = true,
      } | Source,
  } target
in
let spec =
  {
    name = "rustc-%{version}",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "rustc-1.98.1.answers" } | Local, # sha256 pins for the seal check in build.sh; unpinned today
      # The -src tarball ships .cargo/config.toml (crates-io -> vendored-sources) and vendor/, so no
      # cargo-vendor input is needed.  build.sh asserts src/version and the src/stage0 pairing.
      {
        url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
        sha256 = "be1816e7f6c40abb90245ad6e024bed2a7e88d7dda4561e4d5470207df616b9f",
        extract = true,
        strip_prefix = "rustc-%{version}-src",
      } | Source,
      # stage0: the previous rung's installed prefix, /usr/lib/rustc-<stage0_version>/bin/{rustc,cargo}
      # + lib/rustlib/<triple>/lib.  build.sh pins bootstrap.toml [build] rustc/cargo at it.
      stage0,
      base, # userland; xz extracts the source
      cmake, # some vendored -sys build scripts; also pulls in a real curl, shadowed by build.sh's stub
      curl, # libcurl for curl-sys (pkg-config path or the marked vendored submodule)
      libssh2, # LIBSSH2_SYS_USE_PKG_CONFIG=1 makes libssh2-sys use the system lib
      pkgconf, # pkg-config for the -sys probes
      python, # x.py
      toolchain, # gcc/binutils/glibc/linux_headers: clang's sysroot
    ],
    runtime_deps = [
      libffi,
      llvm, # clang, clang++, llvm-config and libLLVM-21.so; also present at build time
      openssl,
      sqlite,
      subsetOf gcc ["libgcc", "libstdcpp"],
    ],
    # no `needs` block: the rung must be strictly offline.

    cmd = "./build.sh",
    outputs = {
      # One recursive OutputData glob over the private prefix: the toolchain is consumed as data by
      # the next rung via absolute path and must not land on /usr/bin.  build.sh prunes the prefix
      # to bin/ + lib/ + BUILDINFO so nothing is left uncaptured.
      toolchain = { glob = "usr/lib/rustc-%{version}/**", allow_executable = true } | OutputData,
    },

    attrs =
      {
        upstream_version = version,
        license_spdx = "MIT OR Apache-2.0",
        source_provenance = {
          category = 'GithubRepo,
          owner = "rust-lang",
          repo = "rust",
        },
        env_state_wiring = {
          env_var = "CARGO_HOME",
          prefix = "cargo",
        },
        # system LLVM + clang, comparable to packages/rust
        build_cost_multiple = 4,
      } | Attrs,
  } | BuildSpec
in
spec
