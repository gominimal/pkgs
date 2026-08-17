#!/bin/sh
# Evict the target package's cache slot (tree + meta) so the NEXT build is
# forced to be real — the missing `--rebuild` knob, implemented with rm.
#
# Scoped hard to ONE package's slot: the cache is spec-keyed, so deleting the
# slot found via the target's meta cannot touch anything else. Used by
# rc-rebuild between build 1 and build 2; without this, build 2 cache-hits
# silently and a diff would compare one build with itself.
set -eu
pkg="$(tr -d ' \n\r\t' < .repro-target)"
CACHE=/var/lib/minimal/cache/built

# ALL matching metas, not head -1: a package accumulates one meta per spec
# variant (published + perturbed), and deleting only the first can evict the
# WRONG slot — measured on tamarin-prover as silent cache hits surviving a
# daemon restart, because the live slot was never actually removed.
n=0
for m in $(grep -ls "\"Spec\":\"$pkg\"" "$CACHE"/meta/*/*.json 2>/dev/null); do
    rel="${m#"$CACHE"/meta/}"; rel="${rel%.json}"
    rm -rf "$CACHE/${rel:?}" "$m"
    echo "evicted $rel (tree + meta)"
    n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "evict: no cache meta for '$pkg' — nothing to evict"; exit 0; }
echo "evicted $n slot(s) for '$pkg' — next build must be real"
# Diagnostic: the daemon ignored an eviction once (silent 'hit' on a deleted
# slot) — list any index-ish files at the cache root that might also need
# invalidating, so the mechanism is visible in the run log.
echo "cache root after evict:"
ls -la "$CACHE" 2>/dev/null | head -8
