#!/bin/sh
set -e

# BEDROCK ROOT (arm64, minimermetic#16): the arm bootstrap Go is no longer a go.dev bindist —
# it is go-1.24.9 from the hex0-rooted arm ladder (hex0 -> gccgo-15.2.0 -> go-1.17.13 ->
# 1.20.14 -> 1.22.6 -> 1.24.9; gccgo is C++ inside the gcc tarball we already mirror, so no
# new trust root; Go 1.5 was the first arm64 port so go-1.4 cannot root this arch). The sealed
# tarball is staged with `extract = true` and appears at ./go in the build root. On arm a
# go.dev bindist in the build root FAILS SHUT — it can only mean the spec silently regressed
# to an unattested binary root. amd64 keeps the go.dev bindist bootstrap until its own
# ladder-close lands (PR 2 of #16).
case $(uname -m) in
  x86_64)  GOARCH=amd64 ;;
  aarch64) GOARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ -x go/bin/go ]; then
  # arm64: the hex0-rooted arm-ladder GOROOT, harness-extracted to ./go by `extract = true`.
  # MOVE it aside FIRST — the `tar -xof go*.src.tar.gz` below untars the go SOURCE tree into
  # this same ./go path, and extracting over the bootstrap would corrupt both.
  mv go bootstrap-go
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap-go"
  BOOTVER="$(GOROOT="${GOROOT_BOOTSTRAP}" "${GOROOT_BOOTSTRAP}/bin/go" version 2>&1 || true)"
  case "${BOOTVER}" in
    *go1.24.9*) : ;;
    *) echo "go: FATAL hex0-rooted arm bootstrap reports '${BOOTVER}', expected go1.24.9" >&2; exit 1 ;;
  esac
  echo "go: bootstrap root = HEX0-ROOTED arm ladder ./bootstrap-go (${BOOTVER})" >&2
elif [ -f "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" ]; then
  if [ "${GOARCH}" = arm64 ]; then
    # RETIRED PATH on arm — fail SHUT.  A go.dev bindist tarball in the arm build root means
    # the spec regressed to an unattested binary root; building anyway would let it back in
    # silently.
    echo "go: FATAL bindist go${MINIMAL_ARG_VERSION}.linux-arm64.tar.gz present but the go.dev arm bindist bootstrap is RETIRED (minimermetic#16); refusing to build on an unattested root" >&2
    exit 1
  fi
  # amd64: go.dev bindist bootstrap, unchanged until the amd64 ladder-close (PR 2 of #16).
  mkdir -p bootstrap
  tar -xof "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" -C bootstrap
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap/go"
else
  echo "go: FATAL no bootstrap Go (neither ./go from the arm ladder tarball nor an amd64 bindist)" >&2
  exit 1
fi

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
