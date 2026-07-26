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

# Create wrapper scripts for the main CLI tools
for bin in gcloud gsutil bq; do
  cat > "${OUTPUT_DIR}/usr/bin/${bin}" << EOF
#!/bin/bash
exec /usr/lib/google-cloud-sdk/bin/${bin} "\$@"
EOF
  chmod +x "${OUTPUT_DIR}/usr/bin/${bin}"
done
