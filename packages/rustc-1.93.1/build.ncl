let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# rustc-1.93.1: builds rustc 1.93.1 from the upstream -src tarball with the rustc-1.92.0 package as
# x.py's stage0, strictly offline, installed to /usr/lib/rustc-1.93.1 (bin/ + lib/ only).
# Same recipe as every rustc-1.9x rung: only version, stage0_version, the stage0 import and the
# Source sha256 differ in this file; VERSION and STAGE0_VERSION differ in build.sh.  See README.md.
let rustc-1-92-0 = import "../rustc-1.92.0/build.ncl" in # the stage0
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

let version = "1.93.1" in
let stage0_version = "1.92.0" in
let amd64_spec =
  {
    name = "rustc-%{version}",
    build_deps = [
      { file = "build.sh" } | Local,
      # The -src tarball ships .cargo/config.toml (crates-io -> vendored-sources) and vendor/, so no
      # cargo-vendor input is needed.  build.sh asserts src/version and the src/stage0 pairing.
      {
        url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
        sha256 = "848c9171212c998c069e6979a205a1a44fa3235a463696d62e24701c83596ce0",
        extract = true,
        strip_prefix = "rustc-%{version}-src",
      } | Source,
      # stage0: the previous rung's installed prefix, /usr/lib/rustc-<stage0_version>/bin/{rustc,cargo}
      # + lib/rustlib/<triple>/lib.  build.sh pins bootstrap.toml [build] rustc/cargo at it.
      rustc-1-92-0,
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
# amd64 only: on arm64 the rustc ladder is consumed as sha-pinned bedrock Sources by the flip
# specs, so this spec collapses to an empty collection there (no build, nothing shipped).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "rustc-%{version}",
      build_deps = [],
    } | BuildSpec,
} target
