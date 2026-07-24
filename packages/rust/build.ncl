let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
let rustc-1-94-1 = import "../rustc-1.94.1/build.ncl" in # ★ THE STAGE0 — final chain rung, CS-attested

let version = "1.95.0" in
{
  name = "rust",
  build_deps = [
    { file = "bootstrap.toml" } | Local,
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
      sha256 = "62b67230754da642a264ca0cb9fc08820c54e2ed7b3baba0289876d4cdb48c08",
      extract = true,
      strip_prefix = "rustc-%{version}-src",
    } | Source,
    # ★ ATTESTED stage0 (issue #17 — the ladder CLOSED).  The stage0 rustc/cargo is now the
    # CS-attested rustc-1.94.1 rung (a build_dep, installed at /usr/lib/rustc-1.94.1/bin), NOT the
    # unattested seed-*.tar.gz tarballs this recipe used to consume.  build.sh points bootstrap.toml's
    # [build] rustc/cargo at that prefix; x.py uses it directly and skips the src/stage0 download.
    #
    # THE CHAIN, all phase=signed in Confidential Space (each rung built by its attested predecessor):
    #   gcc-15.2.0 -> mrustc 0.12.0 -> rustc-1.90.0 -> 1.91.1 -> 1.92.0 -> 1.93.1 -> 1.94.1 -> (THIS)
    #
    # ⚠ WHY 1.94.1, NOT the 1.94.0 pin: rust 1.95.0 compiles stage-0 crates with `--cfg=bootstrap`
    #   (bootstrap cargo.rs:752), and its rustc_macros then references `proc_macro::tracked_env` — an
    #   API 1.94.1 exposes but 1.94.0 does NOT (1.94.0 renamed the module to `tracked`).  A chain-built
    #   1.94.0 stage0 fails with E0432 (proven).  The retired seed was 1.94.1 and built 1.95.0; matching
    #   it (1.94.1 > the 1.94.0 pin — still same-or-one-minor per check_stage0_version) is the fix.  Our
    #   chain build is FAITHFUL — 1.94.0 correctly produced 1.94.0's `tracked`; only the endpoint version
    #   was wrong.  This RETIRES the old seed tarballs — trust moves off the unattested VM onto the chain.
    #
    # ⚠ HONESTY BOUNDARY (do not overstate): the chain is ATTESTED (CS-signed at every rung), NOT
    # byte-SEALED — packages/mrustc ships `# UNPINNED` mrustc.answers.  And attested != hex0-rooted:
    # mrustc's own root provenance (see packages/mrustc) is the remaining boundary, not this edge.
    # assess_dep_chain still returns None on a declaredSources hit, so CHAIN_ENFORCE=1 cannot fail-shut
    # this edge; proof is this recipe's stage0 assert + the predecessor rungs' own signatures.
    # amd64-only for now — arm64's seed-rooted gcc/rust stage0 is a separate track (#16).
    rustc-1-94-1,
    base,
    cmake,
    curl,
    # our seed-rooted stage0 cargo (issue #17) is dynamically linked against
    # libssh2.so.1; curl already brings zlib+openssl, gcc brings libgcc_s.
    libssh2,
    pkgconf,
    python,
    toolchain,
  ],
  runtime_deps = [
    libffi,
    llvm,
    openssl,
    sqlite,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

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
