#!/bin/sh
# archive-zerolen-skip.sh: patch rustc-1.90.0's ArArchiveBuilder::build_inner to skip 0-byte
# archive members.
#
# The mrustc-built rustc emits a 0-byte codegen object for an empty CGU (in practice the
# rustc-std-workspace-core `pub use core::*` shim). ArArchiveBuilder hands that path to memmap2,
# which fails with "memory map must have a non-zero length" and the rustc aborts while building
# libstd. A 0-byte object carries no symbols, so skipping it is semantically free.
#
# Apply before output-<ver>/rustc is built: the failure happens inside the mrustc-built rustc
# when it is used to build libstd. Shipped as a needle-anchored applier rather than a unified
# diff; the count==1 assertion is stricter than `patch --fuzz`.
#
# Usage:  ./archive-zerolen-skip.sh <path-to-rustc-src>
#   e.g.  ./archive-zerolen-skip.sh rustc-1.90.0-src
# Idempotent: re-running on an already-patched tree is a no-op success.
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

# GNU sed: \n in the replacement inserts real newlines. BRE: the needle's ( ) . { are literal
# and it contains no * [ ] \ ^ $.
sed -i \
  "s@${NEEDLE}@&\\n            // ZEROLEN-SKIP: a 0-byte codegen object (empty CGU, e.g. the\\n            // rustc-std-workspace-core \`pub use core::*\` shim) makes memmap2 abort\\n            // (\"memory map must have a non-zero length\"); it carries no symbols, skip it.\\n            if let ArchiveEntry::File(ref zf) = entry {\\n                if std::fs::metadata(zf).map(|m| m.len() == 0).unwrap_or(false) { continue; }\\n            }@" \
  "${AR}"

grep -q "${MARKER}" "${AR}" || { echo "archive-zerolen-skip: FATAL patch did not take" >&2; exit 1; }
echo "archive-zerolen-skip: PATCHED ${AR} (0-byte archive member skip)" >&2
