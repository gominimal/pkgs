#!/bin/sh
set -e

# `unzip` is a thin wrapper that execs libarchive's `bsdunzip` (a runtime dep) —
# the maintained successor to the EOL Info-ZIP unzip. A wrapper script, NOT a
# symlink: the sandbox rejects symlinks pointing outside a package's own output,
# and bsdunzip lives in the libarchive package's output. bsdunzip is a drop-in
# for the flags our callers use (-o/-q/-d/-p); callers keep invoking `unzip`.
mkdir -p "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/unzip" <<'WRAP'
#!/bin/sh
exec /usr/bin/bsdunzip "$@"
WRAP
chmod +x "$OUTPUT_DIR/usr/bin/unzip"
