let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# B6 — coreutils-bedrock-diff  ★ THE DIFFERENTIAL TWIN ★  (scaffolded 2026-07-04)
# Builds the EXACT production coreutils-9.10 (same source tarball, same sha, same configure
# flags, same determinism knobs — see packages/coreutils/build.{ncl,sh}) but with the B5
# FROM-SOURCE toolchain in the compiler slots:
#     gcc      -> gcc-15.2.0-glibc      (B5, seed-rooted, glibc-linked)
#     binutils -> binutils-2.46-glibc   (B5, glibc-linked as/ld/ar/strip)
#     glibc    -> glibc-bedrock-2.42    (B4, cold from-source; versioned sysroot $SR)
# Everything else (base tools, attr/libcap/gmp detection surface) mirrors production so the
# ONLY variable is the toolchain bytes.  The proof artifact feeds
# .staging-ctx/b6-compare.sh (Gate-0 provenance check + normalized byte-compare) against the
# production coreutils release object.  See .staging-ctx/b6-differential-plan-2026-07-03.md.
#
# ⚠ NO replace_on_cycle — EVER.  A prebuilt twin here would reintroduce CAVEAT A (the
#   silent-empty-diff hazard): twinning could substitute prebuilt bytes under this label and
#   make the differential a no-op.  This package must only ever exist as a real build.
# ⚠ NOT a production consumer target.  Downstream packages keep importing ../coreutils; this
#   twin exists solely so B6 has a second artifact to diff.  Do NOT wire it into any closure.
# ⚠ Committing changes to the SEALED B4/B5 rung recipes re-hashes their spec_hash and orphans
#   this twin's chain (wall class 7) — fixes to those rungs ride the B7-cascade re-attest.
# ============================================================================================
# ── B5 from-source toolchain (replaces production binutils/gcc/glibc/linux_headers) ──
let gcc-glibc = import "../gcc-15.2.0-glibc/build.ncl" in # B5: the from-source gcc-15.2.0 driver + glibc runtime libs
let binutils-glibc = import "../binutils-2.46-glibc/build.ncl" in # B5: from-source as/ld/ar/ranlib/strip (install-strip runs THIS strip)
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: versioned sysroot /usr/lib/glibc-bedrock-2.42 (headers+crt+libs+UAPI co-located — no separate linux_headers leaf needed)
# ── base (VERBATIM the production packages/coreutils/build.ncl set, minus the toolchain) ──
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# ── other (production parity: attr/libcap headers+libs must be visible so configure's
#    feature-detection surface — xattr/capability support in ls/cp/mv — matches production) ──
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "9.10" in
{
  name = "coreutils-bedrock-diff",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # IDENTICAL source object + sha as production packages/coreutils/build.ncl — the
      # differential is meaningless unless the input bytes are pinned equal.
      url = "gs://minimal-staging-archives/coreutils-%{version}.tar.xz",
      sha256 = "16535a9adf0b10037364e2d612aad3d9f4eca3a344949ced74d12faf4bd51d25"
    } | Source,
    # ── B5 toolchain slots ──
    gcc-glibc,
    binutils-glibc,
    glibc-bedrock,
    # ── base (production parity) ──
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # ── other (production parity) ──
    attr,
    libcap,
  ],
  runtime_deps = [
    acl,
    glibc-bedrock, # the twin's libc provenance (production coreutils declares production glibc here)
    gmp,
    libcap,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # outputs — VERBATIM production packages/coreutils/build.ncl globs (matching file sets is a
  # precondition of the per-file byte compare), PLUS the B6 provenance breadcrumb.
  outputs = {
    # Core file operations
    ls = { glob = "usr/bin/ls" } | OutputBin,
    cp = { glob = "usr/bin/cp" } | OutputBin,
    mv = { glob = "usr/bin/mv" } | OutputBin,
    rm = { glob = "usr/bin/rm" } | OutputBin,
    mkdir = { glob = "usr/bin/mkdir" } | OutputBin,
    rmdir = { glob = "usr/bin/rmdir" } | OutputBin,
    ln = { glob = "usr/bin/ln" } | OutputBin,
    chmod = { glob = "usr/bin/chmod" } | OutputBin,
    chown = { glob = "usr/bin/chown" } | OutputBin,
    chgrp = { glob = "usr/bin/chgrp" } | OutputBin,

    # Text utilities
    cat = { glob = "usr/bin/cat" } | OutputBin,
    head = { glob = "usr/bin/head" } | OutputBin,
    tail = { glob = "usr/bin/tail" } | OutputBin,
    sort = { glob = "usr/bin/sort" } | OutputBin,
    uniq = { glob = "usr/bin/uniq" } | OutputBin,
    cut = { glob = "usr/bin/cut" } | OutputBin,
    tr = { glob = "usr/bin/tr" } | OutputBin,
    wc = { glob = "usr/bin/wc" } | OutputBin,

    # System utilities
    date = { glob = "usr/bin/date" } | OutputBin,
    whoami = { glob = "usr/bin/whoami" } | OutputBin,
    id = { glob = "usr/bin/id" } | OutputBin,
    pwd = { glob = "usr/bin/pwd" } | OutputBin,
    uname = { glob = "usr/bin/uname" } | OutputBin,

    # Catch-all
    bins = { glob = "usr/bin/*" } | OutputBin,

    libstdbuf = { glob = "usr/libexec/coreutils/libstdbuf.so" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,

    # ★ B6 Gate-0 breadcrumb (usr/share/coreutils-bedrock-diff/B6-TOOLCHAIN.txt): records the
    #   ACTUAL toolchain identity (gcc/as/strip shas, $SR libc sha, PT_INTERP evidence) the twin
    #   built against.  b6-compare.sh EXCLUDES this path from the byte diff and USES it as the
    #   Gate-0 fallback when resolvedDependencies is empty (queue-mode default — see
    #   feedback_verify_deps_permissive_with_empty_resolved).
    b6_toolchain = { glob = "usr/share/coreutils-bedrock-diff/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "coreutils",
      source_provenance = {
        category = 'GnuProject,
        name = "coreutils",
      },
    } | Attrs,

  # NO tests block: the produced binaries carry the PRODUCTION interp /lib64/ld-linux-x86-64.so.2
  # (byte-parity requirement) but this twin's runtime closure is glibc-bedrock, which does NOT wire
  # the /lib64 symlink in a standalone-test sandbox — the tests would fail on exec, not on substance.
  # Correctness is enforced in-build: B6-TWIN-GATE + B6-HELLO-GATE (run gate via explicit loader)
  # + the post-install determinism gates, all fail-shut in build.sh.
} | BuildSpec
