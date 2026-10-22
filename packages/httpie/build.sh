#!/bin/sh
set -ex

# Install httpie's dependency closure from requirements.lock: every distribution
# pinned to one version and its sha256, wheels only, no resolver. Before this,
# build.sh let pip resolve the tree from PyPI at build time, so the shipped
# dependencies (certifi's CA bundle among them) were whatever PyPI served that
# day: not reproducible, and the CA bundle could not be held at a fixed release.
# See requirements.lock for the certifi security floor (CVE-2026-111943) and for
# how to regenerate it.
pip3 install --root "$OUTPUT_DIR" --require-hashes --no-deps --only-binary :all: -r requirements.lock

# httpie itself, from the pinned source tarball, with --no-deps so nothing
# outside the lock can enter. Deliberately NOT --no-build-isolation: httpie's
# build backend is not present in the sandbox, so suppressing isolation makes pip
# fail while preparing the distribution metadata rather than letting it fetch the
# backend it needs. The backend only builds httpie's own wheel; it does not ship.
pip3 install --root "$OUTPUT_DIR" --no-deps .

# Fail closed: a pip that "succeeded" without installing the console scripts
# would otherwise ship a package whose only symptom is a missing command.
if [ ! -x "$OUTPUT_DIR/usr/bin/http" ]; then
  echo "httpie: pip did not install the 'http' entrypoint" >&2
  exit 1
fi

# With --no-deps, a dependency missing from the lock would install cleanly and
# break at import time. `pip check` over the installed tree (plus the python
# runtime dep's own pip, which satisfies httpie's `pip` requirement) turns that
# into a build failure.
SITE="$(ls -d "$OUTPUT_DIR"/usr/lib/python3.*/site-packages)"
PYTHONPATH="$SITE" python3 -m pip check

# CVE-2026-111943: requests verifies TLS against certifi's bundle, so that
# bundle must not trust emSign ECC Root CA - G3 (distrusted by Mozilla after
# eMudhra's intermediate key compromise, bug 2083449). The needle is one line of
# that root's base64 PEM body (its public key).
CACERT="$SITE/certifi/cacert.pem"
[ -s "$CACERT" ] || {
  echo "httpie: no certifi CA bundle at $CACERT" >&2
  exit 1
}
if grep -q 'djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0' "$CACERT"; then
  echo "httpie: certifi still trusts emSign ECC Root CA - G3 (CVE-2026-111943)" >&2
  exit 1
fi
