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

# OpenSSL 4: openssl-sys before 0.9.114 panics in its build script on OpenSSL 4.x.
# Upstream's lock carries a new enough one since 0.169.0 (0.9.118), so the lock patch
# that moved it to 0.9.117 is gone; fail closed if a release ever ships an older one.
osys=$(grep -A1 '^name = "openssl-sys"$' Cargo.lock | sed -n 's/^version = "\(.*\)"$/\1/p')
case "$osys" in
  0.9.*) [ "${osys#0.9.}" -ge 114 ] 2>/dev/null ;;
  0.[1-9][0-9].* | [1-9]*.*) true ;;
  *) false ;;
esac || {
  echo "ERROR: Cargo.lock's openssl-sys ($osys) predates 0.9.114 and fails on OpenSSL 4" >&2
  exit 1
}

# Upstream's release tags set the workspace version in Cargo.toml but leave the
# workspace members at 0.0.0 in the committed Cargo.lock, so `--locked` refuses it
# (rust-v0.169.0: 166 members). Let cargo sync ONLY the workspace members, then
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
# librusty_v8.a with no checksum. codex-cli doesn't reach it (only
# codex-code-mode-runtime and codex-v8-poc do; checked against rust-v0.169.0's
# Cargo.lock), and v8 is also the only path to bindgen/libclang, which is why there
# is no llvm build dep. If codex-cli ever reaches v8, this nonexistent archive path
# makes v8's build script panic instead of downloading; the fix then is a pinned
# `Source` for the archive (RUSTY_V8_ARCHIVE) plus llvm for its bindgen.
export RUSTY_V8_ARCHIVE=/nonexistent/librusty_v8-not-pinned.a

# Deterministic build-time entropy (packages/detbuild, replacing the copy of the shim
# this script used to compile): interposes getrandom/getentropy so build.rs /
# proc-macro / rustc-internal HashMaps iterate in the same order every build. It wraps
# only the offline BUILD (`--frozen` refuses any network access); the produced binary
# is unaffected. The literal one-command prefix is what pkgs' detbuild-preload-guard
# requires; `detbuild` is in build_deps so the library is in the sandbox.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release -p codex-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex

# Shell completions from the built binary (clap_complete via `codex completion <shell>`).
# HOME and CODEX_HOME point at a scratch dir so nothing reads or writes a real ~/.codex.
comp_home=$(mktemp -d)
gen_completion() {
  HOME="$comp_home" CODEX_HOME="$comp_home/.codex" ./target/release/codex completion "$1" > "$2"
  [ -s "$2" ] || { echo "ERROR: empty $1 completion" >&2; exit 1; }
}
mkdir -p "$OUTPUT_DIR/usr/share/bash-completion/completions" \
  "$OUTPUT_DIR/usr/share/zsh/site-functions" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d"
gen_completion bash "$OUTPUT_DIR/usr/share/bash-completion/completions/codex"
gen_completion zsh "$OUTPUT_DIR/usr/share/zsh/site-functions/_codex"
gen_completion fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/codex.fish"
grep -q 'complete -F _codex' "$OUTPUT_DIR/usr/share/bash-completion/completions/codex" ||
  { echo "ERROR: bash completion lacks clap's registration" >&2; exit 1; }
grep -q '^#compdef codex' "$OUTPUT_DIR/usr/share/zsh/site-functions/_codex" ||
  { echo "ERROR: zsh completion lacks #compdef codex" >&2; exit 1; }
grep -q 'complete -c codex' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/codex.fish" ||
  { echo "ERROR: fish completion lacks complete -c codex" >&2; exit 1; }
