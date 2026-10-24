# lib/go.sh: the Go toolchain on PATH. lib/probe.go is compiled in the box
# (CGO off, no module downloads); see its header for what offline proves.

setup_go() {
  mkdir -p "$W/go" && cp "$LIB/probe.go" "$W/go/main.go" && printf 'module probe\n\ngo 1.21\n' > "$W/go/go.mod" \
    && (cd "$W/go" && CGO_ENABLED=0 GOTOOLCHAIN=local GOFLAGS=-mod=mod GOPROXY=off GOCACHE="$W/gocache" GOPATH="$W/gopath" \
          timeout -k 5 300 go build -o probe .)
}
live_go() { to "$W/go/probe" live "https://$1/" "$TIMEOUT" 2>&1 | tail -3; return 0; }
off_go()  { to "$W/go/probe" offline "$1" "$VERIFY_AT_EPOCH" 2>&1 | tail -3; return 0; }
# blocklist variant: the profile's anchors are TRUSTED, so only Go's own
# distrusted-SPKI list can refuse the chain.
live_go_bl() { SSL_CERT_FILE=$W/negctl.pem SSL_CERT_DIR=$W/emptydir live_go "$1"; }
off_go_bl()  { to "$W/go/probe" offline "$1" "$VERIFY_AT_EPOCH" "$W/negctl.pem" 2>&1 | tail -3; return 0; }

row go go "go version | cut -d' ' -f3" live_go off_go "path: x509.Verify, system pool (incl. Go's distrusted-SPKI list)" setup_go
row go-blocklist go "echo go, anchors trusted" live_go_bl off_go_bl "blocklist: x509.Verify with the anchors as roots; only the SPKI list can refuse" setup_go
