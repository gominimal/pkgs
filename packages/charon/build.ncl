# AeneasVerif/charon — the Rust binary that reads Rust source and emits the
# `.llbc` that aeneas consumes. A `rustc_private` tool (charon-driver links the
# compiler's internal librustc_driver.so), so it builds against the pinned
# `rust-nightly-charon` toolchain, offline from a vendored crate set.
#
# Pinned to commit 798016509139eb51f0d764645f76d068d34ba5f6 (v0.1.223) — the same
# commit charon-ml is pinned to. Source is the shared AeneasVerif/charon repo
# tarball; the 347-crate dependency set is vendored (charon-vendor-*.tar.gz) so
# the build is hermetic + offline (no `needs { internet }`).
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust-nightly-charon = import "../rust-nightly-charon/build.ncl" in
let version = "0.1.281" in
{
  name = "charon",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # The AeneasVerif/charon repo (shared with charon-ml); the Rust workspace
      # lives in its charon/ subdir.
      url = "gs://minimal-staging-archives/charon-ml-%{version}.tar.gz",
      sha256 = "62b7e812977136a0a36c197c43a89c90e43ab53932439cc6a1db2f5f8f42e71a",
      extract = true,
      strip_prefix = "AeneasVerif-charon-7980165", # github sha-suffixed top-dir
    } | Source,
    {
      # `cargo vendor` of the charon/ workspace (347 crates + 2 git forks),
      # extracted by build.sh into charon/vendor/ for an offline build.
      url = "gs://minimal-staging-archives/charon-vendor-%{version}.tar.gz",
      sha256 = "386abe0abb8b67cf9da1f7c5b6c2bae5683870f2e24f472351e8033bc4e99ad9",
      extract = false,
    } | Source,
    base,
    rust-nightly-charon,
    gcc,
    toolchain,
  ],
  runtime_deps = [
    # charon shells out to `rustc --print sysroot`; charon-driver dynamically
    # links librustc_driver.so — both need the nightly sysroot present.
    rust-nightly-charon,
    glibc,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  cmd = "./build.sh",
  outputs = {
    charon = { glob = "usr/bin/charon" } | OutputBin,
    charon-driver = { glob = "usr/bin/charon-driver" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "AeneasVerif",
        repo = "charon",
      },
      build_cost_multiple = 3,
    } | Attrs,
  tests = {
    runs =
      {
        class = 'Standalone,
        test_deps = [base, rust-nightly-charon, glibc, zlib, gcc, grep],
        cmds = [
          # --help is before toolchain resolution, so it doesn't need rustup /
          # CHARON_TOOLCHAIN_IS_IN_PATH — just proves the binary links + runs.
          ["/bin/sh", "-c", "/usr/bin/charon --help 2>&1 | grep -qiE 'charon|rustc|cargo|llbc'"],
        ],
      } | Test,
  },
} | BuildSpec
