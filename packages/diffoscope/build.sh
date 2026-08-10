#!/bin/sh
set -e

tar -xof diffoscope-327.tar.gz
cd diffoscope-327

pip3 install --root $OUTPUT_DIR .

# ctypes' find_library() has neither ldconfig nor gcc inside a composed
# root, so libarchive-c cannot locate libarchive.so on its own — but it
# honors $LIBARCHIVE. Ship the console script behind a wrapper that points
# it at the library (overridable, harmless when unset elsewhere).
mv "$OUTPUT_DIR/usr/bin/diffoscope" "$OUTPUT_DIR/usr/bin/diffoscope-real"
cat > "$OUTPUT_DIR/usr/bin/diffoscope" <<'WRAP'
#!/bin/sh
export LIBARCHIVE="${LIBARCHIVE:-/usr/lib/libarchive.so.13}"
exec /usr/bin/diffoscope-real "$@"
WRAP
chmod 755 "$OUTPUT_DIR/usr/bin/diffoscope"

# TODO does not produce /usr/bin/diffoscope
# uv pip install --system --prefix $OUTPUT_DIR/usr -r pyproject.toml --extra cmdline
