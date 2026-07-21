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
    # SEED-ROOTED stage0 (issue #17): rustc + cargo 1.94.1 bootstrapped by mrustc
    # on our own compute — NOT the trust-by-fiat prebuilt 1.94.0.
    # These ARE the official 1.94.1 by source (commit e408947bf), bootstrapped
    # mrustc 0.12.0 -> rustc 1.90.0 -> 1.91.1 -> 1.92.0 -> 1.93.1 -> 1.94.1
    # (verified: our rustc compiles+runs code; see issue #17).
    #
    # ⚠ NOT hex0-rooted, and the seeds are NOT attested. Read before citing this.
    # An earlier version of this comment claimed they were "built from the
    # 229-byte hex0 seed via mrustc". That was FALSE, and it shipped in a signed
    # artifact. What is actually true:
    #   PROVEN     — rust@1.95.0 was built in Confidential Space from THESE exact
    #                tarballs by sha (both appear in the in-toto declaredSources
    #                AND resolvedDependencies; "1.94.0" appears nowhere).
    #   NOT PROVEN — the seeds' own provenance. Built on `rust-ladder`, a plain
    #                GCE VM: no TEE, no attestation, host compiler from
    #                `apt-get install g++` (Debian trixie), mrustc's source
    #                fetched with NO recorded sha anywhere, dtolnay/bootstrap
    #                cloned --depth 1 unpinned. Our own hex0-rooted
    #                stage0-gcc-15.2.0 was NOT used to build them.
    # This moves the trust boundary from "trust Rust's prebuilt binaries" to
    # "trust our unattested build VM". Real progress; not a source root.
    #
    # ⚠ These seeds are also structurally un-fail-shut-able: assess_dep_chain
    # anchors its trust set on declaredSources shas and returns None on a hit, so
    # CHAIN_ENFORCE=1 can never flag them however they were produced. Do not read
    # a green chain gate as evidence about the seed.
    # Because their version/sha differ from 1.95.0's src/stage0 manifest (which
    # pins 1.94.0), they do NOT use the build/cache/<date> pre-place path —
    # build.sh extracts them and points bootstrap.toml's [build] rustc/cargo at
    # them, so x.py uses them directly and skips the src/stage0 download (exactly
    # as the mrustc chain's own rung configs do). The rustc tarball bundles its
    # sysroot (bin/rustc + lib/, i.e. rust-std), so only two Sources are needed.
    # NB: shas are of OUR packaged tarballs. "2026-07-18" is a path LABEL, not the
    # upload date; the tarballs were uploaded 2026-07-20T17:46Z and a CS build has
    # consumed them since — see docs/rust-seed-stage0-bridge.md (outer repo).
    # amd64-only for now — arm64 needs the aarch64 seed-rooted stage0 (#16).
    {
      url = "gs://minimalmertic-hermetic-mirror/rust-stage0-seed/2026-07-18/seed-rustc-1.94.1-x86_64-unknown-linux-gnu.tar.gz",
      sha256 = "99c538b75dd4d007bb7034dbc2c4b39b2fc661b8c1eb1cce5361c3c2235aeee0",
      extract = false,
    } | Source,
    {
      url = "gs://minimalmertic-hermetic-mirror/rust-stage0-seed/2026-07-18/seed-cargo-1.94.1-x86_64-unknown-linux-gnu.tar.gz",
      sha256 = "6b34c8c415e36e59c8025ffb04dbe39318dec000906a87808f17ccd9425ad0c7",
      extract = false,
    } | Source,
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
