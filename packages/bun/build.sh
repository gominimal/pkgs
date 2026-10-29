#!/bin/sh
set -ex
# The system_ca_store_default standalone test (build.ncl) runs only when bun
# rebuilds: tests are not part of the spec hash (gominimal/pkgs#1149).

# Extract and set up bootstrap bun binary
case $(uname -m) in
  x86_64)  BUN_ARCH=x64;   CARGO_TARGET=x86_64-unknown-linux-gnu ;;
  aarch64) BUN_ARCH=aarch64; CARGO_TARGET=aarch64-unknown-linux-gnu ;;
esac
unzip -o "bun-linux-${BUN_ARCH}.zip"
chmod +x "bun-linux-${BUN_ARCH}/bun"
export PATH="$(pwd)/bun-linux-${BUN_ARCH}:$PATH"
bun --version

# Set compilers to use LLVM/Clang
export CC=clang
export CXX=clang++

# Ensure Cargo/Rust can find the C compiler and linker
# (Cargo looks for "cc" by default which may not exist)
export "CARGO_TARGET_$(echo $CARGO_TARGET | tr 'a-z-' 'A-Z_')_LINKER=clang"

# Optimization flags
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# bun pins a nightly toolchain via rust-toolchain.toml; remove it so the build
# uses minimal's stable rust. As of 1.3.14 that alone isn't enough — the release
# lol-html build opts into -Zbuild-std + -Cpanic=immediate-abort (nightly-only,
# to shave ~230KB). Route lol-html to bun's existing stable -Cpanic=abort path
# (precompiled std) instead; the verify-grep makes a future bun build-script
# change fail loudly rather than silently revert to the broken nightly path.
# See gominimal/pkgs#228.
rm -f rust-toolchain.toml
sed -i 's|if (cfg.release && canBuildStdImmediateAbort) {|if (false) { // minimal: stable rust, no -Zbuild-std (pkgs#228)|' scripts/build/deps/lolhtml.ts
grep -q 'no -Zbuild-std (pkgs#228)' scripts/build/deps/lolhtml.ts || { echo "ERROR: lol-html stable-build patch did not apply — bun's build scripts changed; revisit gominimal/pkgs#228." >&2; exit 1; }

# arm64: cap zig's LLVM codegen shard count (gominimal/pkgs — bun hangs on the
# 72-core res-server-arm64). bun's local build profile sets
# -Dllvm_codegen_threads=availableParallelism() (scripts/build/zig.ts,
# codegenThreads), i.e. 72 shards here. Every cold arm64 build stalled at
# exactly "zig obj -> bun-zig.{0..71}.o" with zero cache writes for 6 hours
# until the watchdog killed it (three sandboxes, 2026-09-19/20/21); amd64 with
# 144 shards completes. Upstream never ships above 8 shards (their ASAN CI
# value; releases use 1 for full IPO), so pin arm64 to 8. Verify-grep so a
# future zig.ts refactor fails loudly instead of silently restoring 72.
if [ "$(uname -m)" = aarch64 ]; then
  sed -i 's|^  return availableParallelism();$|  return 8; // minimal: arm64 hangs at 72 codegen shards (pkgs bun/arm64-zig-codegen-cap)|' scripts/build/zig.ts
  grep -q 'arm64 hangs at 72 codegen shards' scripts/build/zig.ts || { echo "ERROR: zig codegen-thread cap did not apply — bun's scripts/build/zig.ts changed; revisit the arm64 hang." >&2; exit 1; }
fi

# CVE-2026-111943: remove the three emSign roots NSS 3.131.1 dropped from the
# compiled-in root store (see the patch header). Applied by name, never a glob,
# so a patch that stops being fetched fails the build. `patch` can exit 0 on an
# already-applied hunk, so also prove the labels are gone and the store still
# has a sane size. The built binary is checked by fingerprint further down.
patch -Np1 -i cve-2026-111943-remove-emsign-roots.patch
for label in "emSign ECC Root CA - G3" "emSign Root CA - C1" "emSign ECC Root CA - C3"; do
  if grep -qF "/* $label */" packages/bun-usockets/src/crypto/root_certs.h; then
    echo "ERROR: CVE-2026-111943 root '$label' still in root_certs.h" >&2
    exit 1
  fi
done
roots=$(grep -c 'BEGIN CERTIFICATE' packages/bun-usockets/src/crypto/root_certs.h)
[ "$roots" -ge 100 ] || { echo "ERROR: root_certs.h has only $roots roots after the CVE-2026-111943 patch" >&2; exit 1; }

# Fingerprint check run against a bun binary: none of the removed roots may be
# in tls.rootCertificates (the compiled-in store), by SHA-256 of the DER, and
# the store must have at least 100 roots so an empty one cannot pass.
cat > ./minimal-check-emsign-roots.js <<'JS'
const { X509Certificate, createHash } = require("node:crypto");
const { rootCertificates } = require("node:tls");
const removed = {
  "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b": "emSign ECC Root CA - G3",
  "125609aa301da0a249b97a8239cb6a34216f44dcac9f3954b14292f2e8c8608f": "emSign Root CA - C1",
  "bc4d809b15189d78db3e1d8cf4f9726a795da1643ca5f1358e1ddb0edc0d7eb3": "emSign ECC Root CA - C3",
};
const fps = new Set(rootCertificates.map(p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex")));
const left = Object.keys(removed).filter(h => fps.has(h)).map(h => removed[h]);
if (fps.size < 100 || left.length) {
  console.log(`roots=${fps.size} still bundled: ${left.join(", ") || "none"}`);
  process.exit(1);
}
console.log(`roots=${fps.size} ok`);
JS
# Control: the stock bootstrap bun still bundles all three, so the check must
# fail on it, naming all three. Matching the message (not just a non-zero
# exit) means a crash in the check cannot pass as the expected failure.
control=$(bun ./minimal-check-emsign-roots.js || true)
case "$control" in
  *"still bundled: emSign ECC Root CA - G3, emSign Root CA - C1, emSign ECC Root CA - C3") ;;
  *) echo "ERROR: emSign root check did not flag the stock bootstrap bun (got: $control); the check is broken" >&2; exit 1 ;;
esac

# Trust the system CA store (/etc/ssl/certs, from ca-certificates) instead of
# the roots compiled into bun, so a CA removed from ca-certificates
# (CVE-2026-111943, eMudhra) stops being trusted without a bun rebuild
# (gominimal/pkgmgr-rs#1026). bun 1.3.14 has no switch for this:
# --use-system-ca / NODE_USE_SYSTEM_CA=1 only ADD the system roots to the
# compiled-in ones, and --use-openssl-ca is parsed but ignored (fixed upstream
# only on the 1.4 line, oven-sh/bun#46542). See the patch header for the exact
# semantics. Opt out with NODE_USE_SYSTEM_CA=0 (any command) or
# --use-bundled-ca (run/test commands). With no system store at all bun keeps
# its compiled-in roots. Applied by name; the greps make an upstream rewrite of
# either file fail the build instead of silently dropping the default.
patch -Np1 -i system-ca-store-default.patch
grep -q 'pub export var Bun__Node__CAStore: BunCAStore = .system; // minimal: system CA store by default' src/cli/Arguments.zig || { echo "ERROR: bun CA store default patch did not apply to src/cli/Arguments.zig" >&2; exit 1; }
grep -q 'for (size_t i = 0; minimal_bundled && i < root_certs_size; i++) {' packages/bun-usockets/src/crypto/root_certs.cpp || { echo "ERROR: bun CA store default patch did not apply to root_certs.cpp" >&2; exit 1; }
[ "$(grep -c 'Bun__Node__CAStore' packages/bun-usockets/src/crypto/root_certs.cpp)" -ge 4 ] || { echo "ERROR: root_certs.cpp does not read Bun__Node__CAStore after the patch" >&2; exit 1; }

# The system-CA behaviour (system store replaces the compiled-in roots; the
# opt-outs restore them) is NOT checked here: a build-time handshake harness on
# the 1.3.14 bootstrap bun gave unusable answers inside the build sandbox
# (fetch ConnectionRefused, tls.connect "ok" against a keyless fake server).
# The grep guards above prove the patch applied; the behaviour is verified by
# the standalone `system_ca_store_default` test in a session before merge.

# Initialize a git repo so nested dep version generation works
# (it runs "git rev-parse HEAD" to get version strings for bundled packages)
git init -q
git -c user.email=build@local -c user.name=build commit -q -m "v${MINIMAL_ARG_VERSION}" --allow-empty

# Build via bun's own build orchestration (handles bun install, codegen, cmake
# deps, zig, linking, and strip). Outputs the stripped binary at build/release/bun.
bun run build:release

# CVE-2026-111943: the binary we ship must not bundle the removed roots.
build/release/bun ./minimal-check-emsign-roots.js

# Install. The real binary lives in libexec; /usr/bin carries wrappers so
# `bun add -g` lands its bins in ~/.local/bin (on the session PATH) rather
# than the off-PATH cache-derived default. bun 1.3.14 reads two narrow knobs
# (PackageManagerOptions.zig, openGlobalBinDir and openGlobalDir), and the
# wrapper defaults both:
#   - BUN_INSTALL_BIN: where the global bin symlinks go.
#   - BUN_INSTALL_GLOBAL_DIR: the global package dir those symlinks point
#     into. Without it bun falls back to $XDG_CACHE_HOME/.bun/install/global
#     (the session sets XDG_CACHE_HOME), so clearing the cache would leave
#     every ~/.local/bin entry dangling.
# A caller's own value of either wins, and a caller's BUN_INSTALL disables
# both defaults so its bin/ and install/global stay as they expect. The env
# vars do outrank bunfig's globalBinDir/globalDir. bunx stays an argv0
# symlink next to the real binary so bun's name-based multiplexing keeps
# working. See gominimal/inbox#584.
mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/libexec/bun"
install -m 755 build/release/bun "$OUTPUT_DIR/usr/libexec/bun/bun"
ln -s bun "$OUTPUT_DIR/usr/libexec/bun/bunx"
for cmd in bun bunx; do
  cat > "$OUTPUT_DIR/usr/bin/$cmd" <<WRAPPER
#!/bin/sh
if [ -n "\${HOME:-}" ] && [ -z "\${BUN_INSTALL:-}" ]; then
  : "\${BUN_INSTALL_BIN:=\$HOME/.local/bin}"
  : "\${BUN_INSTALL_GLOBAL_DIR:=\$HOME/.local/share/bun/global}"
  export BUN_INSTALL_BIN BUN_INSTALL_GLOBAL_DIR
fi
exec /usr/libexec/bun/$cmd "\$@"
WRAPPER
  chmod +x "$OUTPUT_DIR/usr/bin/$cmd"
done

# Shell completions (gominimal/inbox#470).
#
# Use the COMMITTED files at completions/bun.{bash,zsh,fish}, NOT
# `bun completions <shell>`. At this tag the binary picks the shell from
# basename($SHELL) alone and never reads its positional argument, so
# `bun completions zsh` emits whatever $SHELL says — the bash script — or
# errors out under /bin/sh. It also installs a bunx symlink outside
# $OUTPUT_DIR as a side effect. The committed files are the same bytes the
# binary would embed.
install -D -m 0644 completions/bun.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/bun"
install -D -m 0644 completions/bun.fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/bun.fish"
install -D -m 0644 completions/bun.zsh  "$OUTPUT_DIR/usr/share/zsh/site-functions/_bun"

# bun.zsh defines _bun() and helpers but never CALLS _bun — it ends with
# `compdef _bun bun`, which is the sourced-from-rc idiom. Under zsh autoload
# the whole file becomes the body of _bun, so the first Tab would merely
# redefine the function and return no matches. Append a self-invocation so the
# autoloaded form actually completes on first use.
printf '\n_bun "$@"\n' >> "$OUTPUT_DIR/usr/share/zsh/site-functions/_bun"

# Content assertions — existence alone would pass for a bash script in _bun.
[ -s "$OUTPUT_DIR/usr/share/bash-completion/completions/bun" ]
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/bun.fish" ]
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_bun" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_bun" | grep -qx '#compdef bun'
# NB: assert the fish CONSTRUCT, not `complete -c bun`. Some upstreams
# parameterise the command (bat does `set bat {{PROJECT_EXECUTABLE}}` and emits
# `complete -c $bat`), so embedding the name fails on them. Pair it with a
# negative check that this is not another shell's script.
grep -q 'complete -c' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/bun.fish"
! grep -qi 'bash completion' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/bun.fish"
