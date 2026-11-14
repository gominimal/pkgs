#!/bin/sh
set -ex
# The system_ca_store_default standalone test (build.ncl) runs only when bun
# rebuilds: tests are not part of the spec hash (gominimal/pkgs#1149). Touch
# this comment when that test changes, so the next build runs it. Last test
# change: removal direction + opt-out probes (pkgs#1134 review).

# Extract and set up bootstrap bun binary
case $(uname -m) in
  x86_64)  BUN_ARCH=x64;   CARGO_TARGET=x86_64-unknown-linux-gnu ;;
  aarch64) BUN_ARCH=aarch64; CARGO_TARGET=aarch64-unknown-linux-gnu ;;
esac
unzip -o "bun-linux-${BUN_ARCH}.zip"
chmod +x "bun-linux-${BUN_ARCH}/bun"
export PATH="$(pwd)/bun-linux-${BUN_ARCH}:$PATH"
bun --version

# Set compilers to use LLVM/Clang: LLVM 23 from the prefixed llvm-23. bun 1.4.x's
# configure rejects any clang / ld.lld outside the pinned release series (23.1.x:
# scripts/build/ci-images/spec.ts pins.llvm, tools.ts LLVM_VERSION_RANGE). Put the
# prefix first so the bare `clang` used for CC / the cargo linker is the same LLVM 23
# configure resolves.
export PATH="/usr/lib/llvm-23/bin:$PATH"
case "$(clang --version)" in
  *"clang version 23.1."*) ;;
  *) echo "ERROR: bun 1.4.x needs clang 23.1.x first on PATH (llvm-23); got: $(clang --version | head -1)" >&2; exit 1 ;;
esac
sed -n '/^  llvm: {$/,/^  },$/p' scripts/build/ci-images/spec.ts | grep -qE '^    version: "23\.1\.[0-9]+",$' || { echo "ERROR: bun's pinned LLVM (scripts/build/ci-images/spec.ts pins.llvm) is no longer 23.1.x; move bun to the matching llvm line" >&2; exit 1; }
# bun's link reads LLVM bitcode from clang and rustc, and configure refuses a rustc
# whose LLVM major differs from clang's (scripts/build/config.ts). Say so up front.
case "$(rustc -vV)" in
  *"LLVM version: 23."*) ;;
  *) echo "ERROR: bun 1.4.x needs rustc built on LLVM 23 to match clang; got: $(rustc -vV | grep '^LLVM version')" >&2; exit 1 ;;
esac
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

# bun 1.4 is written in Rust and pins a nightly (rust-toolchain.toml): it uses
# #![feature] gates and always rebuilds std from source (-Zbuild-std, so it
# needs rust's rust-src, which the rust package ships). Empty the toolchain
# file so the build uses minimal's stable rust rather than asking rustup for the
# nightly, and let that stable rustc/cargo accept the nightly-only features and
# -Z flags. If the stable release lags the pinned nightly far enough that a
# feature gate changed shape, the Rust compile fails here; the fix is a newer
# rust, not a pin. (1.3.x's lol-html -Zbuild-std sed is gone: lol-html is a
# workspace crate now, and every crate builds that way.) The arm64 zig
# codegen-shard cap (bun/arm64-zig-codegen-cap) is gone too: 1.4 has no Zig.
# Empty it rather than delete it: bun's ninja graph lists rust-toolchain.toml
# as an input of rust-target/plan.json (scripts/build/rust.ts planEdgeInputs), so
# a missing file fails with "missing and no known rule to make it". With no
# `channel` line, config.ts/tools.ts set no RUSTUP_TOOLCHAIN (our rustc is not
# a rustup proxy and would ignore it anyway).
grep -q '^channel = "nightly-' rust-toolchain.toml || { echo "ERROR: bun's rust-toolchain.toml no longer pins a nightly channel; revisit the toolchain handling below" >&2; exit 1; }
: > rust-toolchain.toml
export RUSTC_BOOTSTRAP=1
# bun 1.4.3+ needs Rust >= 1.100: bun_collections calls core::mem::type_info::of
# and lint_js.rs derives Default over std::sync::Once (once_default), both new
# in 1.100.
rust_minor=$(rustc --version | sed -nE 's/^rustc 1\.([0-9]+)\..*/\1/p')
[ -n "$rust_minor" ] || { echo "ERROR: cannot parse rustc --version: $(rustc --version)" >&2; exit 1; }
[ "$rust_minor" -ge 100 ] || { echo "ERROR: bun 1.4.3+ needs rustc >= 1.100; got 1.$rust_minor" >&2; exit 1; }
test -d "$(rustc --print sysroot)/lib/rustlib/src/rust/library" || { echo "ERROR: rust-src missing from the rust sysroot; bun 1.4 builds std with -Zbuild-std" >&2; exit 1; }
# Rust 1.100 stabilized part of `allocator_api` and moved the rest (Vec::new_in as
# a const fn, among others) to `allocator_ext`. bun's pinned nightly predates the
# split, so 12 bun crate roots in 1.4.4 still enable allocator_api: on one line,
# in a list (bundler, shell_parser) or across lines (collections). Under bun's
# -D warnings, 1.100 rejects that gate (stable_features), and which crates need
# the moved part differs: renaming the gate left bun_ptr and bun_shell_parser with
# an unused allocator_ext (unused_features). So leave bun's gates alone and put
# both lines at the top of every crate root that enables allocator_api: the
# moved part for the crates that use it, and an allow for the two lints that
# only describe the split. Crate roots are the files with a `#![feature`; the
# token match skips `allocator_api2`.
alloc_ext='#![feature(allocator_ext)]'
alloc_allow='#![allow(stable_features, unused_features)]'
alloc_crates=$(grep -rlE --include='*.rs' '^#!\[feature' src | xargs grep -lE '(^|[(, [:space:]])allocator_api([,)[:space:]]|$)' || true)
for f in $alloc_crates; do
  { printf '%s\n%s\n' "$alloc_ext" "$alloc_allow"; cat "$f"; } > "$f.minimal-alloc"
  mv "$f.minimal-alloc" "$f"
  echo "allocator_ext + allow: $f"
done
for f in $alloc_crates; do
  [ "$(sed -n 1p "$f")" = "$alloc_ext" ] && [ "$(sed -n 2p "$f")" = "$alloc_allow" ] || { echo "ERROR: $f does not start with the allocator_ext lines" >&2; exit 1; }
done
echo "allocator_api crate roots patched: $(echo "$alloc_crates" | grep -c . || true)"

# CVE-2026-111943: upstream dropped the three emSign roots NSS 3.131.1 removed
# in oven-sh/bun#46159 (bun-v1.4.x), so the 1.3.x patch is gone. Prove the
# source still agrees, by label in the generated list, before building. The
# built binary is checked by fingerprint further down.
for label in "emSign ECC Root CA - G3" "emSign Root CA - C1" "emSign ECC Root CA - C3"; do
  if grep -qxF "$label" packages/bun-usockets/root_certs.txt; then
    echo "ERROR: CVE-2026-111943 root '$label' is back in root_certs.txt" >&2
    exit 1
  fi
done
roots=$(grep -c . packages/bun-usockets/root_certs.txt)
[ "$roots" -ge 100 ] || { echo "ERROR: root_certs.txt lists only $roots roots" >&2; exit 1; }

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
# Control: the same check with one removed root swapped for ISRG Root X1,
# which bun does bundle, must fail and name it. Matching the message (not just
# a non-zero exit) means a crash in the check cannot pass as the expected
# failure. (The stock bootstrap bun no longer bundles the emSign roots, so it
# can no longer serve as the control.)
sed 's/^  "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b": "emSign ECC Root CA - G3",$/  "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6": "ISRG Root X1",/' \
  ./minimal-check-emsign-roots.js > ./minimal-check-emsign-control.js
grep -q '"ISRG Root X1"' ./minimal-check-emsign-control.js || { echo "ERROR: emSign control script was not built" >&2; exit 1; }
control=$(bun ./minimal-check-emsign-control.js || true)
case "$control" in
  *"still bundled: ISRG Root X1") ;;
  *) echo "ERROR: emSign root check did not flag a bundled root (got: $control); the check is broken" >&2; exit 1 ;;
esac
rm -f ./minimal-check-emsign-control.js

# Trust the system CA store (/etc/ssl/certs, from ca-certificates) instead of
# the roots compiled into bun, so a CA removed from ca-certificates
# (CVE-2026-111943, eMudhra) stops being trusted without a bun rebuild
# (gominimal/pkgmgr-rs#1026). bun 1.4.4 has no switch for this:
# --use-system-ca / NODE_USE_SYSTEM_CA=1 only ADD the system roots to the
# compiled-in ones, and --use-openssl-ca is parsed but ignored (fixed upstream
# after 1.4.4, oven-sh/bun#46542). See the patch header for the exact
# semantics. Opt out with NODE_USE_SYSTEM_CA=0 (any command) or
# --use-bundled-ca (run/test commands). With no system store at all bun keeps
# its compiled-in roots. Applied by name; the greps make an upstream rewrite of
# either file fail the build instead of silently dropping the default.
patch -Np1 -i system-ca-store-default.patch
grep -q 'pub static Bun__Node__MinimalCAStore: core::sync::atomic::AtomicU8' src/bun_core/Global.rs || { echo "ERROR: bun CA store default patch did not apply to src/bun_core/Global.rs" >&2; exit 1; }
grep -q 'Bun__Node__MinimalCAStore.store(store, Ordering::Relaxed);' src/bun_core/Global.rs || { echo "ERROR: Global.rs does not record the CA store flag after the patch" >&2; exit 1; }
grep -q '^  if (minimal_bundled) {$' packages/bun-usockets/src/crypto/root_certs.cpp || { echo "ERROR: bun CA store default patch did not apply to root_certs.cpp" >&2; exit 1; }
[ "$(grep -c 'Bun__Node__MinimalCAStore' packages/bun-usockets/src/crypto/root_certs.cpp)" -ge 4 ] || { echo "ERROR: root_certs.cpp does not read Bun__Node__MinimalCAStore after the patch" >&2; exit 1; }
grep -q 'if (!minimal_upstream_ca_store() || !bundled.count(' packages/bun-usockets/src/crypto/root_certs.cpp || { echo "ERROR: root_certs.cpp still drops compiled-in duplicates from the OpenSSL default file when the compiled-in set is not in the store" >&2; exit 1; }

# The system-CA behaviour (system store replaces the compiled-in roots; the
# opt-outs restore them) is NOT checked here: it needs ca-certificates and the
# openssl CLI, which are not build deps. The grep guards above prove the patch
# applied; the standalone `system_ca_store_default` test (build.ncl) checks the
# behaviour on the built bun.

# Initialize a git repo so nested dep version generation works
# (it runs "git rev-parse HEAD" to get version strings for bundled packages)
git init -q
git -c user.email=build@local -c user.name=build commit -q -m "v${MINIMAL_ARG_VERSION}" --allow-empty

# Build via bun's own build orchestration (handles bun install, codegen, cmake
# deps, the Rust crates, linking, and strip). Outputs the stripped binary at build/release/bun.
#
# Bounded (gominimal/pkgs#1160): the arm64 build intermittently hangs with no
# output, and an unbounded hang holds build-bot until someone cancels it. A cold
# 1.3.x build took 3-9 min on either arch; 1.4 compiles every Rust crate and
# std from source, so the limit is 120 min until a 1.4 build-bot timing is
# known. Five minutes before the limit the watchdog prints every live process, so a hang
# names the step it stuck in (cargo/rustc, codegen scripts, cmake deps, bun
# install) instead of ending as a bare timeout. timeout signals its whole
# process group, so rustc and the cmake children die with bun.
# The watchdog's sleep runs as its own child with every fd on /dev/null, so it
# never holds the build's stdout/stderr open, and the TERM trap kills it when
# the build finishes; otherwise `kill $BUN_WATCHDOG` left the sleep running
# with the build's stderr inherited (a runner waiting for EOF would block).
(
  trap 'kill "$s" 2>/dev/null; exit 0' TERM
  sleep 6900 </dev/null >/dev/null 2>&1 &
  s=$!
  wait "$s"
  echo "bun build:release still running after 115 min; live processes:" >&2
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    printf '  %s %s\n' "${d#/proc/}" "$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null | cut -c1-300)" >&2
  done
) &
BUN_WATCHDOG=$!
rc=0
timeout --kill-after=60 7200 bun run build:release || rc=$?
kill "$BUN_WATCHDOG" 2>/dev/null || true
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  echo "ERROR: bun build:release hung for 120 min on $(uname -m) and was killed (gominimal/pkgs#1160)." >&2
  exit 1
fi
[ "$rc" -eq 0 ] || exit "$rc"

# CVE-2026-111943: the binary we ship must not bundle the removed roots.
build/release/bun ./minimal-check-emsign-roots.js

# Install. The real binary lives in libexec; /usr/bin carries wrappers so
# `bun add -g` lands its bins in ~/.local/bin (on the session PATH) rather
# than the off-PATH cache-derived default. bun 1.4.4 reads two narrow knobs
# (src/install/PackageManager/PackageManagerOptions.rs), and the
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
# `bun completions <shell>`. At bun-v1.3.14 the binary picked the shell from
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
