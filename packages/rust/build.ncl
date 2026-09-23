let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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
let rustc-1-97-1 = import "../rustc-1.97.1/build.ncl" in # the stage0
let version = "1.98.1" in
{
  name = "rust",
  build_deps =
    [
      { file = "bootstrap.toml" } | Local,
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
        sha256 = "be1816e7f6c40abb90245ad6e024bed2a7e88d7dda4561e4d5470207df616b9f",
        extract = true,
        strip_prefix = "rustc-%{version}-src",
      } | Source,
      base,
      cmake,
      curl,
      # the stage0 cargo is dynamically linked against libssh2.so.1
      libssh2,
      pkgconf,
      python,
      toolchain,
    ]
    # stage0 = the rustc-1.97.1 rung (1.98.1's src/stage0 pins 1.97.1), built by the chain
    # gcc-15.2.0 -> mrustc 0.12.0 -> rustc-1.90.0 -> 1.91.1 -> ... -> 1.96.0.  amd64 takes the
    # rung build_dep; arm64 takes a sha-pinned tarball of the same rung.  build.sh injects it
    # into bootstrap.toml [build] rustc/cargo; x.py never downloads a stage0.
    @ (
      match {
        { arch = 'Amd64, .. } => [rustc-1-97-1],
        { arch = 'Arm64, .. } =>
          [
            # arm64 stage0: rustc-1.97.1 built by the same rung recipes on arm64 hardware.  The
            # tarball bundles the libLLVM.so.21.1 it links (built with all targets; the llvm
            # package here omits experimental ones) and that library's non-glibc dependencies,
            # each with an $ORIGIN RUNPATH.  `extract = true` unpacks it to ./rustc-1.97.1-aarch64
            # inside the source root; build.sh points bootstrap.toml [build] rustc/cargo at it.
            {
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/de0724a4bf882c5f4641dc6edd6284ee0fa565a405d4ea264a4f305e3bfe5e6e/rustc-1.97.1-aarch64.tar.zst",
              sha256 = "de0724a4bf882c5f4641dc6edd6284ee0fa565a405d4ea264a4f305e3bfe5e6e",
              extract = true,
            } | Source,
          ],
      } target
    ),
  # The build itself is offline (build.sh stubs curl/wget/git and fails on any attempt). The flags stay
  # because the builder grants a package network access when ANY of its dependencies declares it, and
  # the Rust programs that depend on this package still fetch their crates during their own builds.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  runtime_deps = [
    # libssh2 must also be a runtime dep: the shipped cargo carries a DT_NEEDED on libssh2.so.1.
    libssh2,
    libffi,
    llvm,
    openssl,
    sqlite,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    # rust-gdb/rust-lldb require a shell, but in practice they are always gonna be used in an environment with a shell
    # so its better just to disable the lint
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,

    librustc_driver = { glob = "usr/lib/librustc_driver*.so" } | OutputLib,
    rustlib = { glob = "usr/lib/rustlib/**", allow_executable = true } | OutputData,
    rust-analyzer-proc-macro-srv = { glob = "usr/libexec/rust-analyzer-proc-macro-srv" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
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
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
