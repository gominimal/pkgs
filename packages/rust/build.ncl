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
    # rust stage0 bootstrap toolchain (rustc/cargo/rust-std 1.94.0 — the
    # previous stable that bootstraps 1.95.0). Declared as `extract =
    # false` Sources so minimal's normal source hydration drops the
    # tarballs into the build CWD; build.sh then moves them into
    # build/cache/<date>/ where x.py's bootstrap looks, instead of
    # curling static.rust-lang.org (no network egress in Confidential
    # Space). shas must match the rust source's own src/stage0 manifest.
    # amd64-only for now — an arm64 target needs the aarch64 stage0
    # tarballs (tracked under #16). Bumping rust = update these three
    # URLs/shas + the date fallback in build.sh together.
    {
      url = "gs://minimalmertic-hermetic-mirror/rust-stage0/2026-03-05/rustc-1.94.0-x86_64-unknown-linux-gnu.tar.xz",
      sha256 = "31a0d3ac9383dfdeb4fce86eeed5ade3230131c635264c0eab7252dbf235f28e",
      extract = false,
    } | Source,
    {
      url = "gs://minimalmertic-hermetic-mirror/rust-stage0/2026-03-05/cargo-1.94.0-x86_64-unknown-linux-gnu.tar.xz",
      sha256 = "8e17624f3de39e079845bfb25ed15a042f4b50ceca78e37c56c4b9b15949b9f7",
      extract = false,
    } | Source,
    {
      url = "gs://minimalmertic-hermetic-mirror/rust-stage0/2026-03-05/rust-std-1.94.0-x86_64-unknown-linux-gnu.tar.xz",
      sha256 = "dd33653107c36e040082050d9e547e64dac5b456ba74069430d838c00c189a05",
      extract = false,
    } | Source,
    base,
    cmake,
    curl,
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
