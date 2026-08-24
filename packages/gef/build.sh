#!/bin/sh
set -eux

# A GitHub tag archive arrives named after the URL's last component — for
# `.../archive/refs/tags/2026.01.tar.gz` that is `2026.01.tar.gz`, NOT
# `gef-2026.01.tar.gz`. Extract whatever tarball is here rather than encoding a
# guess: the failure mode for guessing wrong is tar's "Error is not
# recoverable", which says nothing useful.
for t in *.tar.gz; do
    [ -f "$t" ] || continue
    tar -xof "$t"
done

# The archive expands to `gef-<version>/`, but locate the file rather than
# assume — this is the second thing that would break silently on an upstream
# repackaging.
GEF_PY=$(find . -name gef.py -maxdepth 3 -type f | head -1)
if [ -z "$GEF_PY" ]; then
    echo "cannot find gef.py after extraction; tree is:" >&2
    ls -la >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/share/gef" "$OUTPUT_DIR/usr/bin"
cp "$GEF_PY" "$OUTPUT_DIR/usr/share/gef/gef.py"

# A LAUNCHER, not a dotfile edit. Upstream's install instructions append a
# `source` line to ~/.gdbinit, which would make this package mutate the user's
# home directory and silently change the behaviour of every unrelated `gdb`
# invocation on the system. Ship a separate entry point instead: `gef` is gdb
# with gef loaded, and `gdb` stays exactly what it was.
#
# -q suppresses the banner so gef's own header is the first thing you see.
# -x sources gef BEFORE the target is loaded, which is what gef expects; any
# further args (a binary, --args, -p PID) are forwarded untouched.
cat > "$OUTPUT_DIR/usr/bin/gef" << 'EOF'
#!/bin/sh
exec gdb -q -x /usr/share/gef/gef.py "$@"
EOF
chmod 755 "$OUTPUT_DIR/usr/bin/gef"
