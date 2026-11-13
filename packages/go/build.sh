#!/bin/sh
set -e

# Start from an empty $OUTPUT_DIR: a persistent build root could leave a stale partial install
# that the output globs would capture.
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"

# Bootstrap Go: the go-1.24.9 build_dep (gominimal/bootstrap), hydrated read-only at
# /usr/lib/go-1.24.9. `go build` may write into GOROOT/pkg, so bootstrap from a writable copy.
BOOT=/usr/lib/go-1.24.9
[ -x "${BOOT}/bin/go" ] || { echo "go: FATAL no bootstrap Go at ${BOOT}" >&2; exit 1; }
cp -a "${BOOT}" "$(pwd)/bootstrap-go"
export GOROOT_BOOTSTRAP="$(pwd)/bootstrap-go"
BOOTVER="$(GOROOT="${GOROOT_BOOTSTRAP}" "${GOROOT_BOOTSTRAP}/bin/go" version 2>&1 || true)"
case "${BOOTVER}" in
  *go1.24.9*) : ;;
  *) echo "go: FATAL bootstrap reports '${BOOTVER}', expected go1.24.9" >&2; exit 1 ;;
esac
echo "go: bootstrap ${BOOTVER}" >&2

tar -xof "go${MINIMAL_ARG_VERSION}.src.tar.gz"
cd go/src
export GOFLAGS="-trimpath"
# GOTOOLCHAIN=local: Go 1.21+ would otherwise download a newer toolchain if a go.mod asks for one.
export GOTOOLCHAIN=local
# TMPDIR: Go's dist falls back to a hardcoded /var/tmp, which does not exist in the sandbox.
GOTMP="$(pwd)/../../gotmp"; mkdir -p "${GOTMP}"; export TMPDIR="${GOTMP}"
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
