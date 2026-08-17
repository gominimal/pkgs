#!/bin/sh
# Snapshot the target package's current cache tree into $1, between builds.
#
# Mandatory, not defensive: the cache is keyed by SPEC hash, not content, so a
# second `min build --rebuild` lands in the SAME slot and RENAME_EXCHANGE
# replaces the first tree. Without this copy-aside there is nothing left to diff.
set -eu
dest="$1"
pkg="$(tr -d ' \n\r\t' < .repro-target)"
CACHE=/var/lib/minimal/cache/built

# NOT `head -1`: a package accumulates one meta per spec variant, and
# snapshotting an arbitrary one hands the caller evidence from a DIFFERENT
# build than the one it just ran — the sibling evictor had this exact bug
# (it deleted the wrong slot; tamarin's "silent cache hits" were that).
# Ambiguity here corrupts evidence silently, so refuse rather than guess.
matches="$(grep -ls "\"Spec\":\"$pkg\"" "$CACHE"/meta/*/*.json 2>/dev/null | sort)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "${n:-0}" -ge 1 ] || { echo "no cache meta for '$pkg' under $CACHE" >&2; exit 1; }
if [ "$n" -gt 1 ]; then
    echo "AMBIGUOUS: $n cache slots claim Spec=$pkg — refusing to guess which build this is:" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
    echo "(evict the stale ones first: min run evict)" >&2
    exit 4
fi
m="$matches"
rel="${m#"$CACHE"/meta/}"; rel="${rel%.json}"
[ -d "$CACHE/$rel" ] || { echo "meta $rel has no tree at $CACHE/$rel" >&2; exit 1; }

rm -rf "$dest"
mkdir -p "$dest"
cp -a "$CACHE/$rel" "$dest/"
# The pkg name is printed so the DRIVER can verify we snapped what it built:
# the worktree (including .repro-target) freezes at activation on v0.5.0, so
# a stale session silently snapshots the WRONG package otherwise (measured:
# a bzip2 run snapped zlib's slot).
echo "snapshot $dest <- $rel  (pkg: $pkg, $(find "$dest" -type f | wc -l | tr -d ' ') files)"
