#!/bin/sh
set -ex

# CS-builder offline path: orch stage npm populates /npm-cache with pyright
# + its deps; install from there with --offline. Outside CS (no /npm-cache),
# fall back to the online registry.
if [ -d /npm-cache ]; then
    # #53: `npm install pyright@VER --offline` returns ENOTCACHED on the pyright
    # PACKUMENT even though the staged cache HAS it — the cache key the fetcher's
    # staging npm wrote differs from this source-built node-25 npm's (a cacache
    # request-key skew we can't reconcile without matching npm builds). Sidestep
    # packument resolution ENTIRELY: locate pyright's tarball in the cache's
    # content-store and `npm install` it DIRECTLY. Installing a local tarball is
    # npm's most basic, version-independent operation — it never touches the
    # request-cache — and pyright bundles its deps, so there's nothing else to
    # resolve offline. Validated locally end-to-end 2026-06-13 ("added 1 package",
    # pyright --version -> 1.1.398).
    echo "=[pyright]= npm $(npm --version 2>&1) / node $(node --version 2>&1)"
    PYTGZ=""
    for b in $(find /npm-cache/_cacache/content-v2 -type f 2>/dev/null); do
        # content-v2 blobs are raw HTTP bodies; tarball bodies are gzipped tars
        # (packument bodies are JSON -> tar fails -> skipped by the grep -q guard).
        if tar -tzf "$b" 2>/dev/null | grep -q "^package/package.json$"; then
            nm=$(tar -xzOf "$b" package/package.json 2>/dev/null \
                 | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
                 | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
            if [ "$nm" = "pyright" ]; then PYTGZ="$b"; break; fi
        fi
    done
    if [ -n "$PYTGZ" ]; then
        echo "=[pyright]= installing tarball directly: $PYTGZ"
        cp "$PYTGZ" ./_pyright-install.tgz
        # NB: /npm-cache is hydrated READ-ONLY, and npm writes tmp/ into its
        # --cache dir (EROFS otherwise). The tarball is self-contained, so point
        # --cache at a fresh writable dir — we don't need the read-only cache here.
        NPMCACHE="$(pwd)/.npmcache"; mkdir -p "$NPMCACHE"
        npm install -g --offline --cache="$NPMCACHE" \
            --prefix=$OUTPUT_DIR/usr ./_pyright-install.tgz
    else
        # Fallback: the packument path (will likely ENOTCACHE, but keep the
        # original behavior so a cache-layout change surfaces loudly).
        echo "=[pyright]= WARN: pyright tarball not found in content-store; packument path"
        npm install -g --offline --cache=/npm-cache \
            --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
    fi
else
    npm install -g --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
fi
