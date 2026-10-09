#!/bin/bash
set -euo pipefail
# `yarn` / `yarnpkg` that hand off to Node's bundled Corepack, which runs the
# exact Yarn release a project pins in package.json's `packageManager`
# (downloaded once into COREPACK_HOME). The download prompt is off: there is
# nobody to answer it under bin/setup, CI or an agent.
for name in yarn yarnpkg; do
  install -d "$OUTPUT_DIR/usr/bin"
  cat > "$OUTPUT_DIR/usr/bin/$name" <<EOF
#!/bin/bash
export COREPACK_ENABLE_DOWNLOAD_PROMPT="\${COREPACK_ENABLE_DOWNLOAD_PROMPT:-0}"
exec /usr/bin/node /usr/lib/node_modules/corepack/dist/$name.js "\$@"
EOF
  chmod 755 "$OUTPUT_DIR/usr/bin/$name"
done
