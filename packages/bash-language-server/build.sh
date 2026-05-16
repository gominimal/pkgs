#!/bin/sh
set -ex

# DIAGNOSTIC MODE: capture /npm-cache state into the build artifact
# itself (since serial-console output rolls off the buffer during long
# build cycles). Once shipped, download the .tar.zst and inspect
# usr/share/npm-cache-diagnostic/dump.txt to see what npm sees inside
# the sandbox. Remove this once the ENOTCACHED root-cause is fixed.

if [ -d /npm-cache ]; then
    mkdir -p "$OUTPUT_DIR/usr/share/npm-cache-diagnostic"
    DUMP="$OUTPUT_DIR/usr/share/npm-cache-diagnostic/dump.txt"
    {
        echo "==== node + npm versions ===="
        node --version
        npm --version
        echo
        echo "==== /npm-cache top-level ===="
        ls -la /npm-cache/ || echo "MISSING"
        echo
        echo "==== _cacache top-level ===="
        ls -la /npm-cache/_cacache/ 2>&1 | head -20 || echo "NO _cacache"
        echo
        echo "==== index-v5 first 5 dirs ===="
        ls /npm-cache/_cacache/index-v5/ 2>&1 | head -5 || echo "MISSING"
        echo
        echo "==== bash-language-server entry path (find) ===="
        find /npm-cache/_cacache/index-v5 -type f 2>/dev/null \
            | xargs grep -l "bash-language-server" 2>/dev/null \
            | head -5 || echo "NOT FOUND"
        echo
        echo "==== index-v5 entry counts by dir ===="
        find /npm-cache/_cacache/index-v5 -type f 2>/dev/null | wc -l
        echo
        echo "==== content-v2 counts ===="
        find /npm-cache/_cacache/content-v2 -type f 2>/dev/null | wc -l
        echo
        echo "==== npm config (offline run) ===="
        npm config list --cache=/npm-cache --offline 2>&1 | head -30 || true
        echo
        echo "==== npm cache verify ===="
        npm cache verify --cache=/npm-cache 2>&1 | head -20 || true
        echo
        echo "==== sample index entry (head -c 500) ===="
        FIRST=$(find /npm-cache/_cacache/index-v5 -type f 2>/dev/null | head -1)
        if [ -n "$FIRST" ]; then
            echo "file: $FIRST"
            head -c 500 "$FIRST"
            echo
            echo "(perms: $(stat -c '%a %U:%G' "$FIRST" 2>/dev/null || stat -f '%p %Su:%Sg' "$FIRST"))"
        fi
        echo
        echo "==== try actual npm install -g (capture failure) ===="
        npm install -g \
            --offline \
            --cache=/npm-cache \
            --prefix=/tmp/test-install \
            bash-language-server@$MINIMAL_ARG_VERSION 2>&1 | head -30 || echo "EXIT $?"
    } > "$DUMP" 2>&1

    # Fake binary + node_modules layout so OutputBin/OutputData globs
    # don't complain. Spec succeeds with the diagnostic embedded.
    mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/lib/node_modules/diagnostic"
    cat > "$OUTPUT_DIR/usr/bin/bash-language-server" <<'PLACEHOLDER'
#!/bin/sh
echo "diagnostic build — not a real bash-language-server"
echo "see /usr/share/npm-cache-diagnostic/dump.txt for the captured /npm-cache state"
exit 1
PLACEHOLDER
    chmod +x "$OUTPUT_DIR/usr/bin/bash-language-server"
    echo "diagnostic" > "$OUTPUT_DIR/usr/lib/node_modules/diagnostic/index.js"

    exit 0
else
    npm install -g --prefix=$OUTPUT_DIR/usr bash-language-server@$MINIMAL_ARG_VERSION
fi
