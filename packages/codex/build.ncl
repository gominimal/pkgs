let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let detbuild = import "../detbuild/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let git = import "../git/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let oniguruma = import "../oniguruma/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in

let version = "0.169.0" in
{
  name = "codex",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "d9b6335151f66d1d4ae9123f55553164ff339f30b14f64a358ea78139c4c093e",
      extract = true,
      strip_prefix = "codex-rust-v%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    pkgconf,
    # aws-lc-sys (rustls -> tokio-tungstenite) builds aws-lc with cmake.
    cmake,
    openssl,
    # Linked instead of the -sys crates' vendored copies (see build.sh).
    sqlite,
    zstd,
    oniguruma,
    bzip2,
    # Deterministic getrandom/getentropy for the offline build (see build.sh).
    detbuild,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
    openssl,
    libcap,
    git,
    subsetOf sqlite ["libs"],
    subsetOf zstd ["libzstd"],
    subsetOf oniguruma ["libs"],
    subsetOf bzip2 ["libs"],
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    codex = { glob = "usr/bin/codex" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/codex" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_codex" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/codex.fish" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openai",
        repo = "codex",
      },
      # Cores it keeps busy (CPU / wall) on the build-bot: arm64 7701 s / 902 s = 8.5,
      # amd64 9173 s / 799 s = 11.5 (pkgs#1713).
      build_cost_multiple = 8,
      env_dir_mappings = [{ read_only = false, path = "~/.codex", class = 'State }],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/codex --version",
  },
} | BuildSpec
