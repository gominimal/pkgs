let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B4.1 — stage0-linux-headers-6.12.43  ★ THE BRIDGE PROOF ★  (2026-07-02)
# The FIRST B4 rung and the FIRST consumer of the R11 pivot (gcc-10.4.0) AS A COMPILER.  Re-roots
# minimal's production linux-headers (packages/linux_headers, same 6.12.43 source + sha) onto the
# seed-rooted toolchain to prove the extract_to_root / toolchain bridge seam end-to-end at ~0 codegen
# risk — BEFORE the heavy glibc-vs-musl target decision.  Both targets need these kernel UAPI headers.
#
# WHY THIS IS SAFE: `make headers` compiles only the host tool scripts/unifdef; the emitted UAPI
# headers are LIBC-INDEPENDENT, so the compiler choice can't change the output bytes (they may even
# come out byte-identical to production's linux_headers artifact — a free cross-check, not required).
#
# DEP MODEL = R10's proven no-multi-gcc-coin-flip shape: the ONLY gcc dep is R11 (pivot) so /usr/bin/gcc
# is unambiguously gcc-10.4.0; R10 binutils-2.41 supplies as/ld (the pivot shells out to them); R7
# musl-1.2.5 is the static link sysroot.  No glibc, no production gcc, no ISL.
# ============================================================================================
let stage0-gcc-10-4-0 = import "../stage0-gcc-10.4.0/build.ncl" in # R11: the PIVOT — HOSTCC for unifdef
let stage0-binutils = import "../stage0-binutils-2.41/build.ncl" in # R10: as/ld the pivot shells out to
let stage0-musl-r7 = import "../stage0-musl-1.2.5/build.ncl" in # R7: /usr/lib/musl-bedrock-1.2.5 sysroot
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # linux-6.12.43 ships .tar.xz
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # kernel Makefiles use awk in places
let version = "6.12.43" in
{
  name = "stage0-linux-headers-6.12.43",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # SAME source + sha as production packages/linux_headers (byte-identical mirror; sha preserved ->
      # sha-pinned resolvedDeps).  extract=false (build.sh untars with --no-same-owner).
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee",
      extract = false,
    } | Source,
    stage0-gcc-10-4-0, # R11 pivot: HOSTCC (via the gcc-cc wrapper in build.sh)
    stage0-binutils, # R10: as/ld/ar/ranlib
    stage0-musl-r7, # R7: static musl sysroot
    bash,
    make,
    sed,
    grep,
    diffutils,
    coreutils,
    tar,
    xz,
    findutils,
    gawk-bootstrap,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # the exported kernel UAPI tree: usr/include/{linux,asm,asm-generic,drm,misc,...}.  Match
    # production linux_headers' glob exactly (kernel UAPI has only subdirs, no top-level *.h).
    includes = { glob = "usr/include/*/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "linux",
      source_provenance = {
        category = 'GithubRepo,
        owner = "torvalds",
        repo = "linux",
      },
    } | Attrs,
} | BuildSpec
