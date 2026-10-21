#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  PLATFORM="x86_64" ;;
  aarch64) PLATFORM="arm" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tar -xof "google-cloud-cli-${MINIMAL_ARG_VERSION}-linux-${PLATFORM}.tar.gz"

# Redistribution guard (gominimal/inbox#284): serving this bundle from the
# public cache is fine because the bundle's own LICENSE is Apache-2.0 — its
# ToS clauses govern *use of GCP services*, not redistribution of the CLI.
# If Google ever changes the bundle license, fail loudly so the
# redistribution question gets re-audited instead of silently shipping.
# Match the Apache-2.0 URL, NOT the phrase "Apache License": the bundle's LICENSE
# wraps it as "...licensed under Apache\nLicense v. 2.0", so a single-line grep for
# "Apache License" never matches (that was the assert's original bug — it failed
# on a genuinely Apache-licensed bundle). The URL sits on one line and is the
# canonical Apache-2.0 marker.
grep -q "apache.org/licenses/LICENSE-2.0" google-cloud-sdk/LICENSE || {
  echo "gcloud bundle LICENSE no longer points at the Apache-2.0 license — re-audit redistribution (gominimal/inbox#284)" >&2
  exit 1
}

mkdir -p $OUTPUT_DIR/usr/{bin,lib}
mv google-cloud-sdk $OUTPUT_DIR/usr/lib/google-cloud-sdk

# Trust the system CA store, not the SDK's own copies (CVE-2026-111943).
#
# The SDK vendors about a dozen CA bundles: certifi for gcloud and for bq,
# gsutil's gslib/data/cacerts.txt and its own certifi, grpc's roots.pem, and
# more. In 581.0.0 six of them still trust "emSign ECC Root CA - G3"
# (SHA-256 86A1ECBA...A36BBE6B), which Mozilla distrusted after eMudhra's
# intermediate key compromise (bug 2083449). 590.0.0, the newest release, ships
# the same bundles, so moving the version does not fix it.
#
# `core/custom_ca_certs_file` does. gcloud reads it for its requests, httplib2
# and gRPC transports, and bin/bootstrapping/{gsutil,bq}.py forward it to
# gsutil (`-o Boto:ca_certificates_file=`) and bq (`--ca_certificates_file=`).
# Setting it in the INSTALLATION properties file (`<sdk root>/properties`, the
# same layer as `gcloud config set --installation`) applies it to every user,
# while an explicit user or env setting can still override it. The path is
# ca-certificates' bundle (a runtime dep). gcloud refuses a value that does not
# name an existing file, so this works only together with that dep.
#
# Fail closed: the shipped properties file must have exactly one [core] section
# and no existing value, and the value must be there afterwards.
PROPS="$OUTPUT_DIR/usr/lib/google-cloud-sdk/properties"
SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
[ -s "$PROPS" ] || {
  echo "gcloud: the SDK no longer ships an installation properties file at $PROPS" >&2
  exit 1
}
[ "$(grep -c '^\[core\]$' "$PROPS")" = 1 ] || {
  echo "gcloud: expected exactly one [core] section in $PROPS" >&2
  exit 1
}
if grep -q '^custom_ca_certs_file' "$PROPS"; then
  echo "gcloud: $PROPS already sets custom_ca_certs_file; re-audit before overriding it" >&2
  exit 1
fi
awk -v line="custom_ca_certs_file = $SYSTEM_CA" '{ print } $0 == "[core]" { print line }' \
  "$PROPS" > "$PROPS.new"
mv "$PROPS.new" "$PROPS"
grep -qx "custom_ca_certs_file = $SYSTEM_CA" "$PROPS" || {
  echo "gcloud: failed to set custom_ca_certs_file in $PROPS" >&2
  exit 1
}
# The value only reaches gsutil and bq because their bootstrap scripts forward
# it. If a future SDK stops doing that, they would silently fall back to their
# vendored bundles, so check that the forwarding is still there.
for tool in gsutil bq; do
  grep -q 'properties.VALUES.core.custom_ca_certs_file' \
    "$OUTPUT_DIR/usr/lib/google-cloud-sdk/bin/bootstrapping/$tool.py" || {
    echo "gcloud: bin/bootstrapping/$tool.py no longer forwards core/custom_ca_certs_file" >&2
    exit 1
  }
done

# Create wrapper scripts for the main CLI tools
for bin in gcloud gsutil bq; do
  cat > "${OUTPUT_DIR}/usr/bin/${bin}" << EOF
#!/bin/bash
exec /usr/lib/google-cloud-sdk/bin/${bin} "\$@"
EOF
  chmod +x "${OUTPUT_DIR}/usr/bin/${bin}"
done
