#!/bin/sh
set -e

# ============================================================================================
# THE LADDER-CLOSE (issue #19).  On amd64 the bootstrap Go is no longer a downloaded go.dev
# bindist — it is /usr/lib/go-1.24.9, the top of our own hex0-rooted ladder:
#
#   hex0 (229 B) -> ... -> gcc-15.2.0-glibc -> go-1.4 (C ONLY: src/cmd/dist is 10 .c / 0 .go)
#     -> go-1.17.13 -> go-1.20.14 -> go-1.22.6 -> go-1.24.9 -> [this go]
#
# arm64 still uses the bindist: Go 1.5 was the first release with an arm64 port, so the C-hosted
# go-1.4 root cannot produce an arm64 toolchain directly (that needs an amd64 host
# cross-bootstrapping via bootstrap.bash — a separate track).  build.ncl's `match target`
# supplies the rung on Amd64 and the bindist Source on Arm64; this script follows whichever
# arrived and says LOUDLY which root it used, so a silent regression to the bindist is visible.
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
elif [ -f "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" ]; then
  # arm64 path (and any future arch with no ladder): the upstream bindist.
  mkdir -p bootstrap
  tar -xof "go${MINIMAL_ARG_VERSION}.linux-${GOARCH}.tar.gz" -C bootstrap
  export GOROOT_BOOTSTRAP="$(pwd)/bootstrap/go"
  echo "go: bootstrap root = UPSTREAM BINDIST (${GOARCH}) — NOT hex0-rooted; see #19 for the arm64 track" >&2
else
  echo "go: FATAL no bootstrap Go (neither ${HEX0_ROOTED_BOOTSTRAP} nor a bindist tarball)" >&2
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
