#!/bin/sh
set -e

# Start from an empty $OUTPUT_DIR: a persistent build root could leave a stale partial install
# that the output globs would capture.
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"

# Bootstrap Go per arch (build.ncl's `match target` stages one of these):
#   amd64: the go-1.24.9 rung build_dep, hydrated read-only at /usr/lib/go-1.24.9.
#   arm64: a sha-pinned go1.24.9 GOROOT tarball, extracted by the harness to ./go.
# The script reports which root it used.  A go.dev bindist fails shut on arm64 and is a loud
# fallback on amd64.
HEX0_ROOTED_BOOTSTRAP=/usr/lib/go-1.24.9
case $(uname -m) in
  x86_64)  GOARCH=amd64 ;;
  aarch64) GOARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ -x "${HEX0_ROOTED_BOOTSTRAP}/bin/go" ]; then
  # amd64: the hydrated rung is read-only and `go build` may write into GOROOT/pkg, so
  # bootstrap from a writable copy.
  cp -a "${HEX0_ROOTED_BOOTSTRAP}" "$(pwd)/bootstrap-go"
elif [ -x go/bin/go ]; then
  # arm64: the hex0-rooted arm-ladder GOROOT, harness-extracted to ./go by `extract = true`.
  # MOVE it aside FIRST — the `tar -xof go*.src.tar.gz` below untars the go SOURCE tree into
  # this same ./go path, and extracting over the bootstrap would corrupt both.
  mv go bootstrap-go
fi
if [ -d bootstrap-go ]; then
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap-go"
  BOOTVER="$(GOROOT="${GOROOT_BOOTSTRAP}" "${GOROOT_BOOTSTRAP}/bin/go" version 2>&1 || true)"
  case "${BOOTVER}" in
    *go1.24.9*) : ;;
    *) echo "go: FATAL hex0-rooted bootstrap reports '${BOOTVER}', expected go1.24.9" >&2; exit 1 ;;
  esac
  echo "go: bootstrap root = HEX0-ROOTED ladder (${GOARCH}) ./bootstrap-go (${BOOTVER})" >&2
elif [ -f "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" ]; then
  if [ "${GOARCH}" = arm64 ]; then
    # RETIRED PATH on arm — fail SHUT.  A go.dev bindist tarball in the arm build root means
    # the spec regressed to an unattested binary root; building anyway would let it back in
    # silently.
    echo "go: FATAL bindist go${MINIMAL_ARG_VERSION}.linux-arm64.tar.gz present but the go.dev arm bindist bootstrap is RETIRED (minimermetic#16); refusing to build on an unattested root" >&2
    exit 1
  fi
  # amd64 fallback when no rung was staged.  build.ncl no longer stages a bindist on amd64,
  # so reaching this means spec drift; say so loudly.
  mkdir -p bootstrap
  tar -xof "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" -C bootstrap
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap/go"
  echo "go: bootstrap root = UPSTREAM BINDIST (${GOARCH}) — NOT hex0-rooted; the amd64 go-1.24.9 rung was expected" >&2
else
  echo "go: FATAL no bootstrap Go (neither the ${HEX0_ROOTED_BOOTSTRAP} rung, ./go from the arm ladder tarball, nor a bindist)" >&2
  exit 1
fi

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
