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
    tar -xof diffoscope-306.tar.gz
    cd diffoscope-306
    pip3 install --prefix=/usr --root "$OUTPUT_DIR" --no-warn-script-location .
fi
