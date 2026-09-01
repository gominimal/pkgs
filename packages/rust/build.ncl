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
let rustc-1-96-0 = import "../rustc-1.96.0/build.ncl" in # ★ THE STAGE0 — final chain rung (ladder EXTENDED for 1.97.1)
let version = "1.97.1" in
{
  name = "rust",
  build_deps =
    [
      { file = "bootstrap.toml" } | Local,
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
        sha256 = "0ed06fdaffd4722a7702e0b4eebfafc897ab8f513e8e1b247cdd7e5c6df6ded2",
        extract = true,
        strip_prefix = "rustc-%{version}-src",
      } | Source,
      # ★ ATTESTED stage0 (issue #17 — the ladder CLOSED, then EXTENDED).  The stage0 rustc/cargo is
      # the CS-attested rustc-1.96.0 rung (a build_dep, installed at /usr/lib/rustc-1.96.0/bin), NOT
      # unattested seed tarballs.  build.sh points bootstrap.toml's [build] rustc/cargo at that
      # prefix; x.py uses it directly and skips the src/stage0 download.
      #
      # THE CHAIN (each rung built by its attested predecessor in Confidential Space):
      #   gcc-15.2.0 -> mrustc 0.12.0 -> rustc-1.90.0 -> 1.91.1 -> 1.92.0 -> 1.93.1 -> 1.94.1
      #     -> 1.95.0 -> 1.96.0 -> (THIS, 1.97.1)
      #
      # ⚠ LADDER EXTENSION (2026-08-27): the upstream 1.95.0 -> 1.97.1 version bump silently
      #   combined with the 1.94.1-rung stage0 in a merge — a bootstrap-window violation
      #   (1.97.1's src/stage0 pins compiler_version 1.96.0; check_stage0_version accepts
      #   same-or-one-minor only, and --cfg=bootstrap API skew breaks even sooner, as the
      #   1.94.0-vs-1.94.1 tracked_env incident proved in miniature).  Rungs rustc-1.95.0 and
      #   rustc-1.96.0 (byte-clones of the 1.94.1 rung recipe) close the gap.
      #
      # ⚠ HONESTY BOUNDARY (do not overstate): the chain is ATTESTED (CS-signed at every rung), NOT
      # byte-SEALED — packages/mrustc ships `# UNPINNED` mrustc.answers.  And attested != hex0-rooted:
      # mrustc's own root provenance (see packages/mrustc) is the remaining boundary, not this edge.
      # assess_dep_chain still returns None on a declaredSources hit, so CHAIN_ENFORCE=1 cannot fail-shut
      # this edge; proof is this recipe's stage0 assert + the predecessor rungs' own signatures.
      # arm64's stage0 is the sealed arm-ladder rung (see the BEDROCK ROOT Source below).
      base,
      cmake,
      curl,
      # our seed-rooted stage0 cargo (issue #17) is dynamically linked against
      # libssh2.so.1; curl already brings zlib+openssl, gcc brings libgcc_s.
      libssh2,
      pkgconf,
      python,
      toolchain,
    ]
    # ★ ATTESTED stage0 on BOTH arches (arm ladder closed 2026-09-01; x.py's stage0
    # download fallback is DELETED from build.sh — a missing stage0 is now fatal).
    @ (
      match {
        { arch = 'Amd64, .. } => [rustc-1-96-0],
        { arch = 'Arm64, .. } =>
          [
            # BEDROCK ROOT (arm64): rustc-1.96.0 from the hex0-rooted arm ladder — sealed
            # arm bedrock toolchain (hex0→gcc-15.2) → mrustc (1d552ca + 11-fix) → 1.90.0 →
            # 1.91.1 → … → 1.96.0, the SAME rung recipes this tree ships for amd64, run
            # verbatim on lab hardware (driver rust-arm-19x.sh v27/R9B; artifacts, per-rung
            # logs and publish provenance: gs://minimalmertic-bootstrap-evidence/
            # arm-rust-ladder/).  Replaces x.py's rust-lang CDN stage0 download.  Known
            # de-risk substitution, recorded loudly: the ladder's LLVM was apt.llvm.org
            # 21.1.5 (no arm CS exists; the pkgs-llvm re-climb is the accepted follow-up).
            # The rung links libLLVM.so.21.1 shared — satisfied by this sandbox's llvm dep
            # (runtime deps are materialized at build time), same shape as the amd64 rungs.
            # `extract = true` unpacks the topdir to ./rustc-1.96.0-aarch64 inside the
            # source root; build.sh points bootstrap.toml [build] rustc/cargo at it.
            {
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/51c984265ceabf3c49a41b6476ed74c6e8439da15b655e86ad79c61197c932ba/rustc-1.96.0-aarch64.tar.zst",
              sha256 = "51c984265ceabf3c49a41b6476ed74c6e8439da15b655e86ad79c61197c932ba",
              extract = true,
            } | Source,
          ],
      } target
    ),
  runtime_deps = [
    # libssh2 must be a RUNTIME dep, not only a build dep: the shipped `cargo` binary
    # carries a DT_NEEDED on libssh2.so.1, so every consumer that runs cargo needs the
    # .so present. Without it cargo dies before it starts:
    #   cargo: error while loading shared libraries: libssh2.so.1: cannot open shared object file
    # (observed on fd@10.3.0; blocks cargo packages generally).
    libssh2,
    libffi,
    llvm,
    openssl,
    sqlite,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  # WHY needs SURVIVES the offline flip: the CS builder has no egress and the attested
  # builds above ran fully offline; with the arm stage0 flip the download path is gone on
  # BOTH arches, so `needs` is retained only for (b) non-CS environments that build this
  # recipe without pre-staged mirrors.  Dropping it entirely is a follow-up.
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
