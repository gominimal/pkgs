let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# rustc-1.91.1 — RUNG 2 of 5 on the road to deleting packages/rust's unattested seed tarballs
# (issue #17).
#
#   RUNG 1  packages/mrustc-rustc-1.90.0   mrustc -> rustc 1.90.0 + cargo + std      [DONE, CS]
#   RUNG 2  packages/rustc-1.91.1  (THIS)  1.90.0 stage0 -> x.py -> rustc 1.91.1
#   RUNG 3  packages/rustc-1.92.0          1.91.1 stage0 -> x.py -> rustc 1.92.0
#   RUNG 4  packages/rustc-1.93.1          1.92.0 stage0 -> x.py -> rustc 1.93.1
#   RUNG 5  packages/rustc-1.94.0 (see ⚠)  1.93.1 stage0 -> x.py -> rustc 1.94.0
#   then    packages/rust deletes its seed-*.tar.gz Sources and consumes RUNG 5 as stage0.
#
# ⚠ ENDPOINT DECISION (blocks RUNG 5 only, NOT this rung): the task named 1.94.1 as the final
#   rung (it matches packages/rust's current seed-rustc-1.94.1 / seed-cargo-1.94.1), but MEASURED:
#   only rustc-1.94.0-src.tar.xz is staged (NOT 1.94.1), and packages/rust/build.ncl says rust
#   1.95.0's src/stage0 PINS 1.94.0.  RECOMMENDATION: build RUNG 5 as 1.94.0 (staged AND pin-
#   matching; 1.95.0 accepts any 1.94.x stage0) and repoint packages/rust [build] rustc/cargo at
#   /usr/lib/rustc-1.94.0 — deletes the seeds with no extra staging.  ALTERNATIVE: stage
#   rustc-1.94.1-src.tar.xz and build 1.94.1 to match the seeds exactly.  Decide before RUNG 5.
#
# ── WHY THIS CLONES packages/rust, NOT the mrustc rung ───────────────────────────────────────
# RUNG 1 was built BY mrustc (a C++->C compiler) via minicargo/run_rustc, which is why it hit
# the cc-linker / archive.rs / git-surface walls and needed a 40x bundled-LLVM build.  From
# RUNG 2 on the compiler is a REAL rustc (the 1.90.0 we just attested) driven by STANDARD x.py.
# So the template is packages/rust/{build.ncl,build.sh,bootstrap.toml} — a SIGNED, working
# recipe — with exactly FOUR deltas, none of them in the x.py core:
#   1. stage0 = the PREVIOUS rung's installed prefix (a build_dep), not seed-*.tar.gz Sources.
#   2. install to a PRIVATE versioned prefix /usr/lib/rustc-1.91.1, NOT /usr/bin — so it does
#      not collide with packages/rust's final toolchain and the next rung can consume it.
#   3. STRICT offline: NO `needs = { dns, internet }`.  packages/rust declares that fallback and
#      so never proves x.py runs with zero network; a chain rung must fail SHUT.  build.sh ports
#      RUNG 1's P0b harness (curl/wget/git stubs, CARGO_NET_OFFLINE, ambient-.cargo guard) AND
#      RUNG 1's P0c vendored-submodule `.git` markers (curl-sys/libssh2-sys — the offline fix a
#      first draft omitted; without it curl-sys hits `git submodule update --init` hours in).
#   4. a FUNCTIONAL gate (compile AND RUN, computed value) after install — never a --version gate.
#
# ── ENVIRONMENT: system LLVM + clang (measured-proven), NOT bundled LLVM ──────────────────────
# packages/llvm is 21.1.8 and rustc 1.91.1 targets LLVM 21, so x.py uses the EXTERNAL
# /usr/bin/llvm-config (bootstrap.toml [target] llvm-config + [llvm] link-shared) and neither
# downloads nor builds LLVM.  This is the packages/rust environment verbatim and closes RUNG 1's
# single biggest provenance/cost hole (RUNG 1 cmake-built LLVM at ~40x).  cc/cxx/linker = clang,
# from packages/llvm, exactly as packages/rust@1.95.0 (also LLVM-21 era) built + signed.
#
# ── OFFLINE IS STRUCTURAL ─────────────────────────────────────────────────────────────────────
# The 1.91.1 source is SELF-CONTAINED: it ships .cargo/config.toml with
# [source.crates-io] replace-with = "vendored-sources" + a bundled vendor/ (measured on the
# staged tarball).  cargo redirects every registry (and the one rust-lang/team git source) to
# vendor/ and fails CLOSED on a miss — no --offline flag is even required.  The network-capable
# calls are all neutralised: (a) the src/stage0 DOWNLOAD, by pinning bootstrap.toml [build]
# rustc/cargo at RUNG 1's binaries; (b) the LLVM download, by external llvm-config; (c) crate
# fetches, by the in-tree vendor redirect; (d) the vendored -sys submodule fetch, by P0c's `.git`
# markers.  build.sh ASSERTS all of these.
#
# ── ⚠ HONESTY BOUNDARY — do not overstate ────────────────────────────────────────────────────
#  * stage0 provenance: RUNG 1 is ATTESTED (CS-signed) but its own anchor packages/mrustc ships
#    `# UNPINNED` mrustc.answers, so this whole chain is GREEN, not byte-SEALED.  This rung ships
#    an UNPINNED, self-arming rustc-1.91.1.answers and is NOT expected to be 2-run byte-identical
#    on the first try (LLVM VC-rev + the cargo metadata-hash surface are untriaged).
#  * NOT hex0-rooted.  The root is mrustc (built by apt g++ on an unattested VM).  This rung
#    moves nothing about that boundary; it only makes the 1.90.0->1.94.x hops attested-in-CS so
#    packages/rust's seed tarballs can be deleted.  Read packages/rust/build.ncl's header.
#  * assess_dep_chain returns None on a declaredSources hit, so CHAIN_ENFORCE=1 can NEVER
#    fail-shut on this edge.  Proof comes from THIS recipe's asserts + gates, nothing downstream.
#  * NOT built end-to-end in CS yet.  This recipe is validated for shell (sh -n), Nickel format,
#    and TOML/sed mechanics; the strict-offline ./x.py build path runs for the FIRST time here.
#    Treat the first CS run as diagnostic — the P0b/P0c tripwires NAME the offending argv/path.
# ============================================================================================
let rustc-1-90-0 = import "../mrustc-rustc-1.90.0/build.ncl" in # ★ THE STAGE0 — attested in CS
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

let version = "1.91.1" in
let stage0_version = "1.90.0" in
{
  name = "rustc-%{version}",
  build_deps = [
    { file = "build.sh" } | Local,
    # rustc 1.91.1 source.  SELF-CONTAINED for offline: ships src/.cargo config + bundled vendor/
    # (measured on the staged tarball: `tar tJ` shows rustc-1.91.1-src/.cargo and vendor/).  So
    # NO goproxy/cargo-vendor inputs are needed, unlike the amd64 cargo pkgs.
    # ⚠ sha256 is task-provided; GCS stores only crc32c/md5, so it is verified by the fetcher's
    # re-hash at stage time (as RUNG 1 does defence-in-depth).  build.sh cannot re-sha an
    # already-extracted tree, so it instead asserts src/version == 1.91.1 and
    # src/stage0 pins compiler_version == 1.90.0 — a STRONGER "right source" check than a sha.
    {
      url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
      sha256 = "66401bb815e236cc6b2aacbbe23b61b286c1fe27a67902e7c0222cfe77b3dbab",
      extract = true,
      strip_prefix = "rustc-%{version}-src",
    } | Source,
    # ★ stage0 = the PREVIOUS rung's installed prefix, consumed as a build_dep.  Its layout is
    # /usr/lib/mrustc-rust-1.90.0/bin/{rustc,cargo} + lib/rustlib/<triple>/lib (std).  build.sh
    # points bootstrap.toml [build] rustc/cargo at bin/rustc (a POSIX-sh wrapper that sets
    # LD_LIBRARY_PATH and execs rustc_binary) and bin/cargo — NOT at rustc_binary directly.
    rustc-1-90-0,
    base,     # bash/coreutils/tar/xz/sed/grep/gawk/findutils — the userland; xz extracts the src
    cmake,    # some vendored -sys build scripts; also pulls a real curl (shadowed by P0b's stub)
    curl,     # libcurl for curl-sys (offline: pkg-config path OR the P0c-marked vendored submodule)
    libssh2,  # LIBSSH2_SYS_USE_PKG_CONFIG=1 -> cargo's libssh2-sys uses the system lib
    pkgconf,  # ships usr/bin/pkg-config for the -sys probes
    python,   # x.py is python
    toolchain, # gcc/binutils/glibc/linux_headers — clang's sysroot (crt, libc, headers)
  ],
  runtime_deps = [
    libffi,
    llvm,     # /usr/bin/{clang,clang++,llvm-config} + libLLVM-21.so (present at BUILD time too)
    openssl,
    sqlite,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  # ── NO `needs` block.  A chain rung MUST be strictly offline and fail SHUT. ──

  cmd = "./build.sh",
  outputs = {
    # ONE recursive OutputData glob over the whole private prefix.  OutputData (raw capture, no
    # PATH/symlink wiring, no interp rewrite) is correct because this toolchain is consumed AS
    # DATA by the next rung via absolute path — it must NOT land on /usr/bin (that is packages/
    # rust's slot).  allow_executable covers the ELF rustc/cargo + the .so's.  Precedent:
    # mrustc-rustc-1.90.0/build.ncl (OutputData+allow_executable over a versioned prefix).
    # build.sh prunes the prefix to bin/ + lib/ + BUILDINFO so this glob is non-empty and there
    # are no uncaptured files (share/man/doc/libexec are removed — the next rung needs none).
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
      # System LLVM + clang -> the same order of magnitude as packages/rust (3), NOT RUNG 1's 40.
      build_cost_multiple = 4,
    } | Attrs,
} | BuildSpec
