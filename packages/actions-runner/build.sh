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
cd "$RUNNER_HOME"
exec ./config.sh "$@"
EOF
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner-config"
