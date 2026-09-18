#!/bin/sh
set -ex

# Exactly diffoscope's invocation — let pip resolve and install the dependency
# tree into this package's own site-packages. Deliberately NOT
# --no-build-isolation: httpie's build backend is not present in the sandbox,
# so suppressing isolation makes pip fail while preparing the distribution
# metadata rather than letting it fetch the backend it needs.
pip3 install --root "$OUTPUT_DIR" .

# Fail closed: a pip that "succeeded" without installing the console scripts
# would otherwise ship a package whose only symptom is a missing command.
if [ ! -x "$OUTPUT_DIR/usr/bin/http" ]; then
  echo "httpie: pip did not install the 'http' entrypoint" >&2
  exit 1
fi
