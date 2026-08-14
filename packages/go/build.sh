#!/bin/sh
set -e

# ============================================================================================
# THE LADDER-CLOSE (issue #19).  The bootstrap Go is no longer a downloaded go.dev bindist on
# EITHER arch — both roots are our own hex0-rooted ladders:
#
#   amd64: hex0 (229 B) -> ... -> gcc-15.2.0-glibc -> go-1.4 (C ONLY: src/cmd/dist is 10 .c /
#          0 .go) -> go-1.17.13 -> 1.20.14 -> 1.22.6 -> go-1.24.9, hydrated at /usr/lib/go-1.24.9
#          (the go-1.24.9 rung package).
#   arm64: hex0 -> ... -> gccgo-15.2.0 (Go 1.5 was the first arm64 port, so go-1.4 cannot root
#          this arch; gccgo is C++ inside the gcc tarball we already mirror) -> go-1.17.13
#          -> 1.20.14 -> 1.22.6 -> go-1.24.9, a mirrored SEALED tarball staged with
#          `extract = true` -> appears at ./go in the build root.
#
# build.ncl's `match target` supplies whichever root fits the arch; this script follows what
# arrived and FAILS SHUT if a go.dev bindist tarball shows up — after the ladder-close a bindist
# in the build root can only mean the spec silently regressed to an unattested binary root.
# ============================================================================================
HEX0_ROOTED_BOOTSTRAP=/usr/lib/go-1.24.9

case $(uname -m) in
  x86_64)  GOARCH=amd64 ;;
  aarch64) GOARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ -x "${HEX0_ROOTED_BOOTSTRAP}/bin/go" ]; then
  # The hydrated rung is READ-ONLY and `go build` can write into GOROOT/pkg, so bootstrap from a
  # writable copy (the lesson the rust ladder's read-only stage0 taught).
  cp -a "${HEX0_ROOTED_BOOTSTRAP}" "$(pwd)/bootstrap-go"
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap-go"
  BOOTVER="$(GOROOT="${GOROOT_BOOTSTRAP}" "${GOROOT_BOOTSTRAP}/bin/go" version 2>&1 || true)"
  case "${BOOTVER}" in
    *go1.24.9*) : ;;
    *) echo "go: FATAL hex0-rooted bootstrap reports '${BOOTVER}', expected go1.24.9" >&2; exit 1 ;;
  esac
  echo "go: bootstrap root = HEX0-ROOTED ${HEX0_ROOTED_BOOTSTRAP} (${BOOTVER})" >&2
elif [ -x go/bin/go ]; then
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
  # RETIRED PATH — fail SHUT.  Both arches are ladder-rooted now; a go.dev bindist tarball in
  # the build root means the spec regressed.  The old behavior (print a banner, build anyway)
  # would let an unattested binary root back in silently.
  echo "go: FATAL bindist go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz present but the go.dev bindist bootstrap is RETIRED (#19); refusing to build on an unattested root" >&2
  exit 1
else
  echo "go: FATAL no bootstrap Go (neither ${HEX0_ROOTED_BOOTSTRAP} nor ./go from the arm ladder tarball)" >&2
  exit 1
fi

tar -xof "go${MINIMAL_ARG_VERSION}.src.tar.gz"
cd go/src
export GOFLAGS="-trimpath"
# GOTOOLCHAIN=local: Go 1.21+ DOWNLOADS a newer toolchain if a go.mod asks for one, which would
# silently smuggle an unattested binary Go into an otherwise seed-rooted build.
export GOTOOLCHAIN=local
# TMPDIR: Go's dist falls back to a hardcoded /var/tmp, which does not exist in the sandbox.
GOTMP="$(pwd)/../../gotmp"; mkdir -p "${GOTMP}"; export TMPDIR="${GOTMP}"
GOROOT=/usr/go ./make.bash # TODO: do ./all.bash once we have /etc setup correctly so those tests will pass

mkdir -p $OUTPUT_DIR/usr/{bin,go}
cp -r ../* $OUTPUT_DIR/usr/go/

for bin in ../bin/*; do
    ln -sv "../go/bin/$(basename "$bin")" "$OUTPUT_DIR/usr/bin/$(basename "$bin")";
done
