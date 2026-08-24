#!/bin/sh
set -e

# Hermetic build path: when /pip-wheels exists (mounted by a SLSA-grade
# builder that has pre-staged the wheelhouse from a sha-verified
# pip_wheels tarball), install diffoscope + its deps from the
# wheelhouse with --no-index + --require-hashes (per-wheel sha
# re-verify). Otherwise fall back to the normal online build for dev
# iteration.
#
# Both paths use --prefix=/usr --root=$OUTPUT_DIR so the diffoscope
# entrypoint script lands at $OUTPUT_DIR/usr/bin/diffoscope to satisfy
# build.ncl's OutputBin glob (pip's default puts scripts at
# $OUTPUT_DIR/usr/local/bin — the longstanding "TODO does not
# produce /usr/bin/diffoscope" bug).
if [ -d /pip-wheels ]; then
    # Pass diffoscope only via -r requirements.txt (which carries the
    # --hash=sha256:... pin). Passing it ALSO on the command line with
    # no --hash fails --require-hashes ("hashes are required... missing
    # from some requirements"), since CLI-specified requirements bypass
    # the file-level hash assertion.
    pip3 install \
        --no-index \
        --no-build-isolation \
        --find-links=/pip-wheels \
        --require-hashes \
        -r /pip-wheels/requirements.txt \
        --prefix=/usr \
        --root="$OUTPUT_DIR" \
        --no-warn-script-location \
        --no-compile
else
    tar -xof diffoscope-329.tar.gz
    cd diffoscope-329
    pip3 install --prefix=/usr --root "$OUTPUT_DIR" --no-warn-script-location .
fi

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
