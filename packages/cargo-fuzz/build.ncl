let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let detbuild = import "../detbuild/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let rust-nightly-charon = import "../rust-nightly-charon/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.13.2" in
{
  name = "cargo-fuzz",
  # `cargo fuzz`: libFuzzer-driven fuzzing for Rust, built from source with the stable
  # rust package. At run time it drives whatever `cargo`/`rustc` is on PATH, and that
  # must be a NIGHTLY (it passes -Zsanitizer / -Cpasses=sancov-module), whose rust-std
  # carries the sanitizer runtimes (librustc-nightly_rt.{asan,lsan,msan,tsan}.a, e.g.
  # rust-nightly-charon). It ships and depends on no toolchain, so a session keeps
  # exactly the one cargo it brings.
  #
  # A session that actually fuzzes also needs a C/C++ toolchain on PATH, which is NOT a
  # runtime dep here: the fuzz crate's libfuzzer-sys dependency compiles libFuzzer's C++
  # sources with the `cc` crate at fuzz time (c++ + libstdc++), and rustc links
  # everything with the target's linker. Add `toolchain` to the session, and since gcc
  # ships no `cc` link (rustc's default linker on linux-gnu), point cargo at gcc:
  # CARGO_TARGET_<TRIPLE>_LINKER=gcc. Without it the first build script fails with
  # "linker `cc` not found". -s thread needs --build-std (rust-src, which
  # rust-nightly-charon ships); -s memory turns it on by itself.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Mirror of https://github.com/rust-fuzz/cargo-fuzz/archive/refs/tags/%{version}.tar.gz
      url = "gs://minimal-staging-archives/rust-fuzz/cargo-fuzz/%{version}.tar.gz",
      sha256 = "88e179805e4fe4c9903720a004ef6903b0f28b27a22e74660cd72f58612f6b46",
      extract = true,
      strip_prefix = "cargo-fuzz-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    # Deterministic getrandom/getentropy for the offline build (see build.sh).
    detbuild,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  # cargo fetch (see build.sh)
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    cargo-fuzz = { glob = "usr/bin/cargo-fuzz" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "cargo-fuzz fuzz --version | grep -qx 'cargo-fuzz %{version}'"],
        ],
      } | Test,
    # `cargo fuzz init` + `cargo fuzz list` on a one-function crate with the nightly the
    # fv-lab loadout uses: cargo finds the cargo-fuzz subcommand on PATH, cargo-fuzz runs
    # `cargo metadata`, writes fuzz/ with a libfuzzer-sys target, and lists it. Nothing is
    # compiled (that needs libfuzzer-sys from crates.io, and tests run offline).
    init_list =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, rust-nightly-charon],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              export CARGO_HOME="$PWD/cargo-home"
              mkdir -p tiny/src
              cd tiny
              printf '[package]\nname = "tiny"\nversion = "0.1.0"\nedition = "2021"\n' > Cargo.toml
              printf 'pub fn parse(d: &[u8]) -> bool {\n    d.first() == Some(&0)\n}\n' > src/lib.rs
              cargo fuzz init --target parse
              grep -q '^libfuzzer-sys' fuzz/Cargo.toml
              grep -q 'fuzz_target!' fuzz/fuzz_targets/parse.rs
              out="$(cargo fuzz list)"
              printf '%s\n' "$out"
              grep -qx 'parse' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-fuzz",
        repo = "cargo-fuzz",
      },
    } | Attrs,
} | BuildSpec
