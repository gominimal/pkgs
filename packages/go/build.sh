#!/bin/sh
set -e

mkdir -p bootstrap
case $(uname -m) in
  x86_64)  GOARCH=amd64 ;;
  aarch64) GOARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
tar -xof "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" -C bootstrap
export GOROOT_BOOTSTRAP="$(pwd)/bootstrap/go"

tar -xof "go${MINIMAL_ARG_VERSION}.src.tar.gz"
cd go/src
export GOFLAGS="-trimpath"
GOROOT=/usr/go ./make.bash # TODO: do ./all.bash once we have /etc setup correctly so those tests will pass

mkdir -p $OUTPUT_DIR/usr/{bin,go}
cp -r ../* $OUTPUT_DIR/usr/go/

# Registry resilience for EVERY Go build (pkgs#648): pipe (not comma) makes
# the toolchain fall back to direct on ANY proxy error — proxy.golang.org
# sheds load under module-download bursts with per-stream HTTP/2 resets that
# go never retries, and the default comma form only falls back on 404/410.
# $GOROOT/go.env is the sanctioned default (go >= 1.21); env vars still win.
if grep -q '^GOPROXY=' "$OUTPUT_DIR/usr/go/go.env" 2>/dev/null; then
    sed -i 's#^GOPROXY=.*#GOPROXY=https://proxy.golang.org|direct#' "$OUTPUT_DIR/usr/go/go.env"
else
    printf 'GOPROXY=https://proxy.golang.org|direct
' >> "$OUTPUT_DIR/usr/go/go.env"
fi

# Two more network paths a build can die on (pkgs#648, same load-shedding):
# - sum.golang.org is its OWN connection; integrity is already guaranteed by
#   each package's go.sum inside its sha256-pinned source tarball, so the
#   live checksum DB is a build-time availability risk with no added trust.
# - GOTOOLCHAIN=auto silently DOWNLOADS a newer toolchain when a go.mod asks
#   for one; builds must use the Go we ship.
for kv in 'GOSUMDB=off' 'GOTOOLCHAIN=local'; do
    k="${kv%%=*}"
    if grep -q "^$k=" "$OUTPUT_DIR/usr/go/go.env" 2>/dev/null; then
        sed -i "s#^$k=.*#$kv#" "$OUTPUT_DIR/usr/go/go.env"
    else
        echo "$kv" >> "$OUTPUT_DIR/usr/go/go.env"
    fi
done

for bin in ../bin/*; do
    ln -sv "../go/bin/$(basename "$bin")" "$OUTPUT_DIR/usr/bin/$(basename "$bin")";
done
