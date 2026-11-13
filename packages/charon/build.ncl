# AeneasVerif/charon — the Rust binary that reads Rust source and emits the
# `.llbc` that aeneas consumes. A `rustc_private` tool (charon-driver links the
# compiler's internal librustc_driver.so), so it builds against the pinned
# `rust-nightly-charon` toolchain, offline from a vendored crate set.
#
# Pinned to commit 7b462d9159db2ed3015162352183906a30bfafc6 (v0.1.304, 2026-10-30) — the same
# commit charon-ml is pinned to. Source is the shared AeneasVerif/charon repo
# tarball; the 338-crate dependency set is vendored (charon-vendor-*.tar.gz) so
# the build is hermetic + offline (no `needs { internet }`).
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust-nightly-charon = import "../rust-nightly-charon/build.ncl" in
let version = "0.1.304" in
{
  name = "charon",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # The AeneasVerif/charon repo (shared with charon-ml); the Rust workspace
      # lives in its charon/ subdir.
      url = "gs://minimal-staging-archives/charon-ml-%{version}.tar.gz",
      sha256 = "445c1e303ccafc5ab5bbf14f2cddde48baaf2a281ba4093ee4e0b2a3dc4ab125",
      extract = true,
      strip_prefix = "AeneasVerif-charon-7b462d9", # github sha-suffixed top-dir
    } | Source,
    {
      # `cargo vendor` of the charon/ workspace (338 crates + 2 git forks),
      # extracted by build.sh into charon/vendor/ for an offline build.
      url = "gs://minimal-staging-archives/charon-vendor-%{version}.tar.gz",
      sha256 = "a41e218c07104d90b12f8e2e3c71fa95a2cde26bc1a1a2d95d1155f6c43da346",
      extract = false,
    } | Source,
    {
      # crates/minirust: a git submodule (Nadrieril/minirust, a fork of
      # minirust/minirust, branch bump-toolchain; Apache-2.0 OR MIT) that GitHub's
      # archive omits. Since charon 75b7a1c ("Use miniutil", after 0.1.281) the default
      # `minirust` feature builds crates/miniutil, whose lib is the submodule's tooling/miniutil/src.
      # Pinned to the gitlink at this charon commit (c0b555e5b15accc6c1366b1d911a1bfd49c3d9d0);
      # re-check `git ls-tree <charon commit> crates/minirust` on every bump.
      # Extracted by build.sh into crates/minirust.
      url = "gs://minimal-staging-archives/charon-minirust-c0b555e.tar.gz",
      sha256 = "4380fe1dbde99cd50b6a452e07021f4474e8a7d290ffff7776f274cb78f952a4",
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
        test_deps = [bash-bootstrap, rust-nightly-charon, glibc, zlib, gcc, grep],
        cmds = [
          # --help is before toolchain resolution, so it doesn't need rustup /
          # CHARON_TOOLCHAIN_IS_IN_PATH — just proves the binary links + runs.
          ["/bin/sh", "-c", "/usr/bin/charon --help 2>&1 | grep -qiE 'charon|rustc|cargo|llbc'"],
        ],
      } | Test,
  },
} | BuildSpec
