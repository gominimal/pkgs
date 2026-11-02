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

# Trust the system CA store (/etc/ssl/certs, from ca-certificates) instead of
# certifi's bundle, so a CA removed from ca-certificates (CVE-2026-111943,
# eMudhra) stops being trusted without an httpie rebuild
# (gominimal/pkgmgr-rs#1026). requests takes its default bundle from
# certifi.where() (requests/certs.py at 2.34.2 says to change where() when
# packaging for a distribution), so where() returns the system bundle whenever
# it exists, as Debian's python-certifi does, and certifi's own cacert.pem
# otherwise. The overrides are appended after certifi's definitions, and
# certifi/__init__.py re-exports them (`from .core import contents, where`).
# A caller still wins with requests' REQUESTS_CA_BUNDLE / CURL_CA_BUNDLE
# (Session.merge_environment_settings, which httpie 3.2.4 calls) or httpie's
# --verify=<path>; pointing either at certifi's cacert.pem restores it.
CORE="$SITE/certifi/core.py"
grep -q '^from \.core import contents, where$' "$SITE/certifi/__init__.py" &&
grep -q '^    def where() -> str:$' "$CORE" || {
  echo "httpie: certifi's layout changed upstream; revisit the system CA default" >&2
  exit 1
}
cat >> "$CORE" <<'PYEOF'


# minimal: prefer the system CA store (see httpie's build.sh).
import os as _minimal_os

_MINIMAL_SYSTEM_CA = "/etc/ssl/certs/ca-certificates.crt"
_minimal_certifi_where = where
_minimal_certifi_contents = contents


def where() -> str:
    try:
        if _minimal_os.path.getsize(_MINIMAL_SYSTEM_CA) > 0:
            return _MINIMAL_SYSTEM_CA
    except OSError:
        pass
    return _minimal_certifi_where()


def contents() -> str:
    path = where()
    if path == _MINIMAL_SYSTEM_CA:
        with open(path, encoding="utf-8") as f:
            return f.read()
    return _minimal_certifi_contents()
PYEOF
# Replace pip's now-stale bytecode with a deterministic (checked-hash) one.
python3 -m compileall -q --invalidation-mode checked-hash "$CORE"
PYTHONPATH="$SITE" python3 - <<'PYEOF'
import certifi, certifi.core
certifi.core._MINIMAL_SYSTEM_CA = "/nonexistent/ca-certificates.crt"
assert certifi.where().endswith("/certifi/cacert.pem"), certifi.where()
assert "BEGIN CERTIFICATE" in certifi.contents()
PYEOF
