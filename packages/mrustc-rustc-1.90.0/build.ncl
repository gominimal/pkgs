let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# mrustc-rustc-1.90.0: rustc 1.90.0 + cargo + libstd compiled by the mrustc/minicargo binaries
# from packages/mrustc, using the gcc-15.2.0-glibc toolchain and glibc-bedrock-2.42 sysroot.
# Installs to the private prefix usr/lib/mrustc-rust-1.90.0/ (no collision with packages/rust);
# the rustc-1.91.1 recipe consumes it as stage0.
#
# The mrustc source tree is re-unpacked here as data only: minicargo.mk, run_rustc/, the
# rustc-1.90.0-src.patch, script-overrides/ and lib/libproc_macro are read from it, and the
# compiler binaries come from packages/mrustc. minicargo.mk:39/:41 declare MRUSTC/MINICARGO
# with `?=` and use them as file prerequisites, so pointing them at the installed binaries
# leaves the .PHONY self-rebuild rules unreferenced.
#
# `$(MRUSTC)` is prerequisite-only on the LIBS/rustc/cargo path; minicargo selects the compiler
# via MRUSTC_PATH (os.cpp:419) or as its own sibling. build.sh exports MRUSTC_PATH and checks
# `mrustc -vV`.
#
# Scope includes run_rustc stages 1-4: run_rustc/Makefile:162 is the first place the
# mrustc-built rustc executes (where archive-zerolen-skip.sh matters), run_rustc/Makefile:218
# is the only step producing dylib std (needed for proc macros), and splitting there would
# strand the cmake-built LLVM across a package boundary.
#
# Offline: the lockfiles contain no git+ sources and vendor/ covers them; minicargo cannot
# fetch (manifest.h:210 has_git() is false). minicargo.mk:221-224's curl rule has no
# prerequisites, so the pre-placed tarball is always up to date. Three vendored build.rs
# (curl-sys x2, libssh2-sys) run `git submodule update --init` behind a `.git` marker check,
# suppressed by empty markers in build.sh P2; wasm-bindgen-shared and cranelift-codegen run a
# bare `git rev-parse HEAD`, which the git stub allows as a local probe. See build.sh P0b.
#
# The shipped rustc carries two patches: mrustc's rustc-1.90.0-src.patch (minicargo.mk:229)
# and archive-zerolen-skip.sh. Both are recorded in BUILDINFO.
let mrustc = import "../mrustc/build.ncl" in # usr/bin/{mrustc,minicargo} + archive-zerolen-skip.sh
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # gcc/g++ 15.2.0 + libstdc++ + libatomic
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot (headers + crt + libs + kernel UAPI)
let zlib = import "../zlib/build.ncl" in
# Not in packages/mrustc's tool list:
let cmake = import "../cmake/build.ncl" in # LLVM configure (minicargo.mk:311). Imports ../curl; build.sh's stub shadows the real curl by PATH order.
let python = import "../python/build.ncl" in # LLVM's CMakeLists requires Python3 at configure time
let perl = import "../perl/build.ncl" in # openssl-src build.rs (minicargo.mk:90 --features vendored-openssl)
let patch = import "../patch/build.ncl" in # minicargo.mk:229 `patch -p0`
let pkgconf = import "../pkgconf/build.ncl" in # usr/bin/pkg-config, probed by several vendored -sys build scripts
let gzip = import "../gzip/build.ncl" in # minicargo.mk:226 `tar -xzf`
# Same as packages/mrustc:
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let findutils = import "../findutils/build.ncl" in # install-phase build-path sweep
let diffutils = import "../diffutils/build.ncl" in # `patch` uses cmp on some paths
let version = "1.90.0" in
let mrustc_version = "0.12.0" in
let mrustc_commit = "1d552cadf1c58bce8b9b431a5714dcea113dde38" in
let amd64_spec =
  {
    name = "mrustc-rustc-1.90.0",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "rustc-1.90.0.answers" } | Local, # byte-seal pins; the seal check arms once populated
      { file = "gatelib.rs" } | Local, # GATE-2: rlib crate (exercises ArArchiveBuilder)
      { file = "gate190.rs" } | Local, # GATE-3: ten std constructs, computed 42, exit codes 111-120
      { file = "gate_pm.rs" } | Local, # GATE-4a: proc-macro crate
      { file = "gate_pm_use.rs" } | Local, # GATE-4b: its consumer
      {
        # .tar.gz is required: minicargo.mk:220 hardcodes rustc-$(RUSTC_VERSION)-src.tar.gz
        # and :226 is `tar -xzf`.
        url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.gz",
        sha256 = "799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e",
        extract = false, # build.sh places it at the mrustc tree root; `make RUSTCSRC` extracts it
      } | Source,
      {
        # Same bytes as packages/mrustc's Source; used as data only (build system + patch), the
        # binaries come from packages/mrustc. Unpatched on purpose: aarch64-support.patch touches
        # only compiler source, which this recipe does not read.
        # Re-derivable: git archive --format=tar --prefix=mrustc-0.12.0/ %{mrustc_commit}
        url = "gs://minimal-staging-archives/mrustc-%{mrustc_version}-git1d552ca.tar",
        sha256 = "1b8a2772e65b283ccbd42cb6a0e94dd2239e59bd4eb866d44405d6b5a0c33314",
        extract = false,
      } | Source,
      mrustc,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      zlib,
      cmake,
      python,
      perl,
      patch,
      pkgconf,
      gzip,
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      findutils,
      diffutils,
    ],
    build_args = {
      include version,
      include mrustc_version,
      include mrustc_commit,
    },
    cmd = "./build.sh",
    outputs = {
      # OutputData + allow_executable rather than OutputBin: the binaries use the sysroot loader
      # at a non-standard .interp, and bin/rustc is a shell wrapper the interpreter checker
      # would reject. `*` is non-recursive, `**` recursive. An empty glob fails enumeration;
      # `dylibs` is non-empty only if run_rustc/Makefile:218 produced dylib std (what GATE-4
      # checks).
      bins = { glob = "usr/lib/mrustc-rust-1.90.0/bin/*", allow_executable = true } | OutputData,
      dylibs = { glob = "usr/lib/mrustc-rust-1.90.0/lib/*.so*", allow_executable = true } | OutputData,
      rustlib = { glob = "usr/lib/mrustc-rust-1.90.0/lib/rustlib/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/mrustc-rust-1.90.0/BUILDINFO" } | OutputData,
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
        # Estimate: LLVM via cmake + LIBS + rustc lowered to C + cargo + four run_rustc stages.
        build_cost_multiple = 40,
      } | Attrs,
  } | BuildSpec
in
# amd64 only: this recipe belongs to the amd64 bootstrap ladder. On arm64 the equivalent
# artifacts are consumed as sha-pinned Sources elsewhere, so the spec is an empty collection
# (no build, no outputs, no dependents).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "mrustc-rustc-1.90.0",
      build_deps = [],
    } | BuildSpec,
} target
