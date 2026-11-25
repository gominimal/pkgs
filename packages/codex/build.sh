#!/bin/bash
set -euo pipefail

cd codex-rs

export CC=gcc
export LD=gcc
# Reproducibility without serial codegen. With upstream's release profile (lto = "thin",
# codegen-units = 4) the binary came out different on every build (2026-10 prod-pair diff:
# 36 of 36 differing symbols were `.llvm.<hash>` names, which ThinLTO gives the locals it
# promotes across modules; 49% of the binary churned; gominimal/inbox#253). That was
# fixed with `-C codegen-units=1` in RUSTFLAGS plus the entropy shim below, but RUSTFLAGS
# put cgu=1 on all ~1070 crates and roughly doubled the build. lto = "off" (not `false`,
# which still runs rustc's crate-local ThinLTO between codegen units) takes ThinLTO out
# entirely, so nothing gets a `.llvm.<hash>` name and every crate keeps cargo's default 16
# codegen units. v0 mangling stays (the other half of the nushell / difftastic fix).
# Checked: two `--rebuild`s (6 and 4 cargo jobs) gave the same usr/bin/codex sha256.
export CARGO_PROFILE_RELEASE_LTO=off
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
# No line tables, stripped symbols: upstream keeps them only so its own packaging can
# archive sidecar symbols before stripping. Panic locations are still embedded strings,
# so the source and cargo-home paths stay remapped.
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_STRIP=symbols
export RUSTFLAGS="-C linker=gcc -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# Link pkgs' C libraries instead of the copies vendored in -sys crates, so a CVE fix in
# sqlite / zstd / oniguruma / bzip2 reaches codex without a codex rebuild of its own
# copy (pkgs' sqlite carries patches the crate's bundled 3.54.1 does not). Each crate
# falls back to its bundled copy silently when pkg-config fails, so the NEEDED check
# after the build fails closed if any of them did. aws-lc-sys, ring and tree-sitter
# have no system-library option and stay bundled.
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1 # libsqlite3-sys 0.39: bundled bindings are for 3.54.1
export ZSTD_SYS_USE_PKG_CONFIG=1       # zstd-sys 2.0.16+zstd.1.5.7
export RUSTONIG_SYSTEM_LIBONIG=1       # onig_sys 69.9: needs oniguruma >= 6.9.3
# bzip2-sys probes pkg-config `bzip2`, but bzip2 1.0.8 ships no bzip2.pc; describe
# pkgs' libbz2 (in /usr/lib) to it.
pcdir=$(mktemp -d)
printf 'Name: bzip2\nDescription: bzip2 compression library\nVersion: 1.0.8\nLibs: -lbz2\nCflags:\n' > "$pcdir/bzip2.pc"
export PKG_CONFIG_PATH="$pcdir${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

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

# The workspace locks `v8` (rusty_v8, a git dependency with Chromium submodules) for
# three members codex-cli does not reach: code-mode-host, code-mode-runtime and v8-poc
# (checked against rust-v0.169.0's Cargo.lock). Cargo checks every git dependency of the
# workspace out, submodules included, even for `-p codex-cli`: a local build spent 413 s
# before its first `Compiling` line, 36 s without it. Dropping the three members and the
# v8 [patch] lets the resolve below prune v8 and the 24 crates only it needed. v8 is also
# the only path to bindgen/libclang (no llvm build dep) and its build script downloads a prebuilt
# librusty_v8.a with no checksum, so if codex-cli ever reaches it the pin check below
# fails (a new registry pin); the fix then is a pinned `Source` for the archive
# (RUSTY_V8_ARCHIVE) plus llvm for its bindgen.
v8_lines='^    "(code-mode-host|code-mode-runtime|v8-poc)",$|^v8 = [{] git = '
[ "$(grep -cE "$v8_lines" Cargo.toml)" = 4 ] || {
  echo "ERROR: Cargo.toml's v8 members / [patch] no longer match; recheck what reaches v8" >&2
  exit 1
}
sed -i -E "/$v8_lines/d" Cargo.toml

# Upstream's release tags set the workspace version in Cargo.toml but leave the
# workspace members at 0.0.0 in the committed Cargo.lock, so `--locked` refuses it
# (rust-v0.169.0: 166 members). Let cargo sync the workspace members (and prune what
# only the dropped members used), then fail closed if any registry or git crate was
# added or its pinned version or source moved. Removals are the v8 prune above.
registry_pins() {
  awk '/^\[\[package\]\]/ { n = ""; v = "" } /^name = / { n = $3 } /^version = / { v = $3 }
       /^source = / { print n, v, $3 }' Cargo.lock | sort
}
pins_before=$(registry_pins)
cargo update --workspace
added=$(comm -13 <(printf '%s\n' "$pins_before") <(registry_pins))
if [ -n "$added" ]; then
  echo "ERROR: cargo update --workspace added or moved a registry crate; only workspace members may change:" >&2
  printf '%s\n' "$added" >&2
  exit 1
fi
if grep -q '^name = "v8"$' Cargo.lock; then
  echo "ERROR: v8 is still in Cargo.lock after dropping its workspace members" >&2
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

# Deterministic build-time entropy (packages/detbuild, replacing the copy of the shim
# this script used to compile): interposes getrandom/getentropy so build.rs /
# proc-macro / rustc-internal HashMaps iterate in the same order every build. It wraps
# only the offline BUILD (`--frozen` refuses any network access); the produced binary
# is unaffected. The literal one-command prefix is what pkgs' detbuild-preload-guard
# requires; `detbuild` is in build_deps so the library is in the sandbox.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release -p codex-cli

# Fail closed if a -sys crate fell back to its vendored copy.
needed=$(readelf -d target/release/codex | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
for lib in libsqlite3.so libzstd.so libonig.so libbz2.so; do
  grep -q "^$lib" <<<"$needed" ||
    { echo "ERROR: codex does not link the system $lib (NEEDED: $(echo $needed))" >&2; exit 1; }
done

# For comparing two builds of the same spec (the reproducibility check).
echo "codex binary: $(sha256sum target/release/codex | cut -d' ' -f1) $(stat -c %s target/release/codex) bytes; NEEDED: $(echo $needed)"

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
