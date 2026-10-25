#!/bin/bash
set -euo pipefail

cd codex-rs

export CC=gcc
export LD=gcc
# codegen-units=1 and v0 mangling: with the default parallel codegen the binary came
# out different on every build (2026-10 prod-pair diff: 36 of 36 differing symbols were
# `.llvm.<hash>` codegen-unit locals, 49% of the 1.25 GB binary churned). The same two
# flags fixed nushell and difftastic (gominimal/inbox#253). The release profile keeps
# line tables and isn't stripped, so both the source and the cargo-home paths are
# remapped, as nushell and zola do.
export RUSTFLAGS="-C linker=gcc -C codegen-units=1 -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# Needed for crates that use bindgen / libclang
export LIBCLANG_PATH="$(dirname $(find /usr/lib -name 'libclang*.so' | head -1))"

# Upstream's release tags set the workspace version in Cargo.toml but leave the
# workspace members at 0.0.0 in the committed Cargo.lock, so `--locked` refuses it
# (rust-v0.164.0: 166 members). Let cargo sync ONLY the workspace members, then
# fail closed if any registry crate's pinned version or source moved.
registry_pins() {
  awk '/^\[\[package\]\]/ { n = ""; v = "" } /^name = / { n = $3 } /^version = / { v = $3 }
       /^source = / { print n, v, $3 }' Cargo.lock | sort
}
pins_before=$(registry_pins)
cargo update --workspace
if [ "$(registry_pins)" != "$pins_before" ]; then
  echo "ERROR: cargo update --workspace moved a registry crate; only workspace members may change" >&2
  diff <(printf '%s\n' "$pins_before") <(registry_pins) >&2 || true
  exit 1
fi

# Security floor (CVE-2026-111943): upstream's own lock now carries rustls-webpki
# 0.103.16 and webpki-roots / webpki-root-certs 1.0.10, so the lock patch is gone.
# Keep failing closed if a pre-fix rustls-webpki 0.103.x or webpki-roots /
# webpki-root-certs 1.0.x ever comes back.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# All network access happens here, with real entropy: crates and git deps are fetched
# (and checked against Cargo.lock) before the shim below is loaded, so no TLS session
# runs with the shim's fixed bytes.
cargo fetch --locked

# The workspace locks `v8` (rusty_v8), whose build script downloads a prebuilt
# librusty_v8.a with no checksum. codex-cli doesn't depend on it at this version
# (only codex-code-mode-runtime and codex-v8-poc do). If that changes, this
# nonexistent archive path makes v8's build script panic instead of downloading;
# the fix then is a pinned `Source` for the archive, passed via RUSTY_V8_ARCHIVE.
export RUSTY_V8_ARCHIVE=/nonexistent/librusty_v8-not-pinned.a

# Deterministic build-time entropy, the shim zola and nushell already use: interposes
# getrandom/getentropy so build.rs / proc-macro / rustc-internal HashMaps iterate in the
# same order every build. It wraps only the offline BUILD (`--frozen` refuses any
# network access); the produced binaries are unaffected.
shim_dir=$(mktemp -d)
cat > "$shim_dir/detrand.c" <<'SHIM'
#include <stddef.h>
#include <sys/types.h>
ssize_t getrandom(void *buf, size_t n, unsigned int flags) {
    unsigned char *p = buf; size_t i;
    for (i = 0; i < n; i++) p[i] = (unsigned char)(0xA5 ^ (i * 157));
    return (ssize_t)n;
}
int getentropy(void *buf, size_t n) { getrandom(buf, n, 0); return 0; }
SHIM
gcc -shared -fPIC -O2 -o "$shim_dir/detrand.so" "$shim_dir/detrand.c"
LD_PRELOAD="$shim_dir/detrand.so" cargo build --frozen --release -p codex-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex
