let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# mrustc 0.12.0: bin/mrustc + bin/minicargo compiled with the gcc-15.2.0-glibc g++ against the
# glibc-bedrock-2.42 sysroot, from a sha-pinned `git archive` of the upstream commit.
# Outputs usr/bin/{mrustc,minicargo}, usr/share/mrustc/patches/archive-zerolen-skip.sh and
# usr/share/mrustc/BUILDINFO. Building rustc with these binaries is packages/mrustc-rustc-1.90.0.
#
# Source pin: upstream's download.sh fetches the GitHub archive with no recorded sha, and
# codeload tarballs are not byte-stable, so the tarball is generated from the commit:
#     git archive --format=tar --prefix=mrustc-0.12.0/ \
#         1d552cadf1c58bce8b9b431a5714dcea113dde38 > mrustc-0.12.0-git1d552ca.tar
#     sha256 1b8a2772e65b283ccbd42cb6a0e94dd2239e59bd4eb866d44405d6b5a0c33314
# The commit is a master commit that still identifies as 0.12 (src/version.cpp asserts in
# build.sh); the commit-qualified basename keeps it distinct from the v0.12.0 tag tarball while
# the archive prefix stays mrustc-0.12.0/. Plain .tar: `git archive`'s tar stream is a pure
# function of the commit, compressor output is not. The master pin is needed because v0.12.0
# cannot build aarch64 libcore (hir/hir.cpp:132 ord TODO, fixed upstream in d8cc2933+dad6c321).
#
# Offline: minicargo.mk:224's curl is only reachable from the RUSTCSRC/LIBS/rustc targets;
# only `all` and `tools/minicargo` are built. build.sh also installs failing curl/wget/git
# stubs and checks that none fired.
#
# Determinism: Makefile:190 compiles version.o with a `date` stamp and four `git` shell-outs
# that land in .rodata and survive strip. build.sh replaces the five `$(shell ...)` calls with
# make variables derived from SOURCE_DATE_EPOCH and the pinned commit, then rebuilds version.o
# later and requires bin/mrustc to be byte-identical. mrustc.answers arms the byte-seal check
# once it contains pin lines.
#
# Runtime shape: bin/mrustc is dynamically linked with .interp under /usr/lib/glibc-bedrock-2.42
# and RUNPATH = that sysroot plus /usr/lib. A consumer needs glibc-bedrock-2.42,
# gcc-15.2.0-glibc (libstdc++.so.6, libgcc_s.so.1) and zlib in its rootfs; no runtime_deps are
# declared, matching the other bedrock recipes.
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # g++ 15.2.0 + libstdc++.so.6, cc1plus, C++ headers
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # /usr/lib/glibc-bedrock-2.42 sysroot (headers + crt + libs + kernel UAPI)
let zlib = import "../zlib/build.ncl" in # Makefile:45 `LIBS := -lz`; src/hir/serialise_lowlevel.cpp:10 includes <zlib.h>
let bash = import "../bash/build.ncl" in # build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # Makefile determinism patch + the libc.so linker-script fixup
let grep = import "../grep/build.ncl" in # assertions
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/nproc/touch/cut/od/date
let tar = import "../tar/build.ncl" in # plain .tar unpack (--no-same-owner)
let patch = import "../patch/build.ncl" in # aarch64-support.patch (unconditional), hir-ord-unevaluated.patch (conditional)
let version = "0.12.0" in
let commit = "1d552cadf1c58bce8b9b431a5714dcea113dde38" in
let amd64_spec =
  {
    name = "mrustc",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "mrustc.answers" } | Local, # byte-seal pins; the seal check arms once populated
      { file = "archive-zerolen-skip.sh" } | Local, # rustc-1.90.0 0-byte archive member fix; shipped, not applied here
      { file = "hir-ord-unevaluated.patch" } | Local, # upstream d8cc2933+dad6c321 backport; already in this pin, applied only when the TODO is present
      { file = "aarch64-support.patch" } | Local, # aarch64 fix series against this pin; also touches shared code, so applied on both arches
      { file = "gate.rs" } | Local, # GATE 1 program
      {
        # Re-derivable from the public repo; see the source pin note above.
        url = "gs://minimal-staging-archives/mrustc-%{version}-git1d552ca.tar",
        sha256 = "1b8a2772e65b283ccbd42cb6a0e94dd2239e59bd4eb866d44405d6b5a0c33314",
        extract = false, # build.sh untars with --no-same-owner (chown is not permitted in the sandbox)
      } | Source,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      zlib,
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      patch,
    ],
    build_args = {
      include version,
      include commit,
    },
    cmd = "./build.sh",
    outputs = {
      # OutputData + allow_executable rather than OutputBin: the binaries use the sysroot loader
      # at a non-standard .interp path, which the interpreter checker would reject.
      bins = { glob = "usr/bin/{mrustc,minicargo}", allow_executable = true } | OutputData,
      patches = { glob = "usr/share/mrustc/patches/*", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/mrustc/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        source_provenance = {
          category = 'GithubRepo,
          owner = "thepowersgang",
          repo = "mrustc",
        },
        build_cost_multiple = 2,
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
      name = "mrustc",
      build_deps = [],
    } | BuildSpec,
} target
