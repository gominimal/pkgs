#!/bin/sh
set -ex

# Pin typescript. Installing it unpinned pulled TypeScript 7.0.2 (the native
# rewrite), which DROPPED the `tsserver` bin entry (its bin is now just `tsc`),
# so the `usr/bin/tsserver` output glob matched nothing and the build failed.
# 5.9.3 is the latest 5.x, still ships tsserver, and is what
# typescript-language-server 4.3.3 targets. Pinning also makes this
# internet-fetching build deterministic instead of tracking npm's `latest`.
npm install -g --prefix=$OUTPUT_DIR/usr \
  typescript-language-server@$MINIMAL_ARG_VERSION \
  typescript@5.9.3
