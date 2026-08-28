#!/bin/sh
# ============================================================================================
# archive-zerolen-skip.sh — the rustc-1.90.0 fix for the mrustc-built rustc's zero-length-mmap
# SIGABRT.  THIS FILE EXISTS TO END A STRAND.
#
# Until it was committed, this fix lived in exactly two places: the rust-ladder VM's 500GB disk
# (us-west1-c, TERMINATED, --no-service-account, no external IP) and an ephemeral macOS
# /private/tmp scratchpad that is wiped on reboot.  It was in no git repo, on no branch, in no
# worktree.  Losing either would have cost a re-derivation of a bug that took a full ladder run
# to surface.
#
# ── THE BUG ──────────────────────────────────────────────────────────────────────────────────
# The rustc that mrustc produces emits a 0-byte codegen object for an empty CGU — in practice the
# rustc-std-workspace-core `pub use core::*` shim.  ArArchiveBuilder::build_inner then hands that
# path to memmap2, which aborts with "memory map must have a non-zero length", taking the whole
# process down with SIGABRT while run_rustc is building libstd.  A 0-byte object carries no
# symbols, so skipping it is semantically free.
#
# ── WHEN TO APPLY ────────────────────────────────────────────────────────────────────────────
# BEFORE building output-<ver>/rustc, not after.  The abort happens inside the mrustc-built rustc
# while it is being USED to build libstd, so a recipe that patches after the rustc rung will not
# clear the wall.  The ordering that worked on the VM was:
#   patch archive.rs -> move aside run_rustc/output-<ver>/prefix-s -> touch archive.rs
#   -> make -f minicargo.mk output-<ver>/rustc -> ... /cargo -> (cd run_rustc && make)
#
# ── STATUS ───────────────────────────────────────────────────────────────────────────────────
# NOT applied by packages/mrustc.  That package builds bin/mrustc + bin/minicargo only and never
# unpacks rustc source.  This script ships as attested output data at
# usr/share/mrustc/patches/archive-zerolen-skip.sh so the downstream rustc rung consumes it from
# the rootfs and its bytes are recorded in mrustc's resolvedDependencies.
#
# It is shipped as a needle-anchored applier rather than a unified diff on purpose: a `.patch`
# needs exact line numbers and context from rustc-1.90.0-src, which is not available to the
# authoring environment.  The count==1 assertion below is a stricter guard than `patch --fuzz`
# would give anyway.
#
# ── UNVERIFIED HERE ──────────────────────────────────────────────────────────────────────────
# The needle and the `ArchiveEntry::File(PathBuf)` variant shape were measured on the VM against
# real 1.90.0 source, not in this checkout.  If upstream 1.90.0 differs, this script aborts
# loudly rather than half-applying.
#
# Usage:  ./archive-zerolen-skip.sh <path-to-rustc-src>
#   e.g.  ./archive-zerolen-skip.sh rustc-1.90.0-src
# Idempotent: re-running on an already-patched tree is a no-op success.
# ============================================================================================
set -eu

SRCROOT="${1:-rustc-1.90.0-src}"
AR="${SRCROOT}/compiler/rustc_codegen_ssa/src/back/archive.rs"
MARKER='ZEROLEN-SKIP'
NEEDLE='for (entry_name, entry) in self.entries {'

[ -f "${AR}" ] || { echo "archive-zerolen-skip: FATAL no such file: ${AR}" >&2; exit 1; }

if grep -q "${MARKER}" "${AR}"; then
  echo "archive-zerolen-skip: already applied to ${AR} (no-op)" >&2
  exit 0
fi

n="$(grep -c -F "${NEEDLE}" "${AR}" || true)"
if [ "${n}" != "1" ]; then
  echo "archive-zerolen-skip: FATAL needle occurs ${n}x in ${AR}, expected exactly 1." >&2
  echo "                      Upstream reshaped build_inner; re-derive the patch, do not fuzz it." >&2
  exit 1
fi

# GNU sed: \n in the replacement inserts real newlines.  BRE — the needle contains ( ) . { which
# are all literal in BRE (`.` matches itself here), and no * [ ] \ ^ $.
sed -i \
  "s@${NEEDLE}@&\\n            // ZEROLEN-SKIP: a 0-byte codegen object (empty CGU, e.g. the\\n            // rustc-std-workspace-core \`pub use core::*\` shim) makes memmap2 abort\\n            // (\"memory map must have a non-zero length\"); it carries no symbols, skip it.\\n            if let ArchiveEntry::File(ref zf) = entry {\\n                if std::fs::metadata(zf).map(|m| m.len() == 0).unwrap_or(false) { continue; }\\n            }@" \
  "${AR}"

grep -q "${MARKER}" "${AR}" || { echo "archive-zerolen-skip: FATAL patch did not take" >&2; exit 1; }
echo "archive-zerolen-skip: PATCHED ${AR} (0-byte archive member skip)" >&2
