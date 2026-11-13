#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

mkdir runner
tar -xof "actions-runner-linux-${ARCH}-${MINIMAL_ARG_VERSION}.tar.gz" -C runner

mkdir -p $OUTPUT_DIR/usr/{bin,lib}
mv runner $OUTPUT_DIR/usr/lib/actions-runner

# Create wrapper script for run.sh
cat > "${OUTPUT_DIR}/usr/bin/actions-runner" << 'EOF'
#!/bin/bash
if [ ! -d "$RUNNER_HOME/bin" ]; then
    echo "Setting up writable runner directory at $RUNNER_HOME..." >&2
    cp -a /usr/lib/actions-runner/. "$RUNNER_HOME/"
fi
# CVE-2026-111943: the bundled externals/node{20,24} trust their compiled-in
# root store, which still holds emSign ECC Root CA - G3. --use-openssl-ca
# makes them trust OpenSSL's default store instead, i.e. our ca-certificates
# (/etc/ssl/cert.pem). The runner's processes inherit this environment, so
# JavaScript actions and node in `run:` steps get it too. A workflow that sets
# its own NODE_OPTIONS replaces it for its steps; one that already chose a
# store keeps its choice.
case " ${NODE_OPTIONS:-} " in
    *" --use-openssl-ca "*|*" --use-bundled-ca "*) ;;
    *) export NODE_OPTIONS="--use-openssl-ca${NODE_OPTIONS:+ $NODE_OPTIONS}" ;;
esac
cd "$RUNNER_HOME"
exec ./run.sh "$@"
EOF
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner"

# Create wrapper script for config.sh
cat > "${OUTPUT_DIR}/usr/bin/actions-runner-config" << 'EOF'
#!/bin/bash
if [ ! -d "$RUNNER_HOME/bin" ]; then
    echo "Setting up writable runner directory at $RUNNER_HOME..." >&2
    cp -a /usr/lib/actions-runner/. "$RUNNER_HOME/"
fi
# CVE-2026-111943: same as actions-runner (bundled node -> our ca-certificates).
case " ${NODE_OPTIONS:-} " in
    *" --use-openssl-ca "*|*" --use-bundled-ca "*) ;;
    *) export NODE_OPTIONS="--use-openssl-ca${NODE_OPTIONS:+ $NODE_OPTIONS}" ;;
esac
cd "$RUNNER_HOME"
exec ./config.sh "$@"
EOF
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner-config"
