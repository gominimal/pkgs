#!/bin/sh
set -ex

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

# Initialize a git repo so nested dep version generation works
# (it runs "git rev-parse HEAD" to get version strings for bundled packages)
git init -q
git -c user.email=build@local -c user.name=build commit -q -m "v${MINIMAL_ARG_VERSION}" --allow-empty

# Build via bun's own build orchestration (handles bun install, codegen, cmake
# deps, zig, linking, and strip). Outputs the stripped binary at build/release/bun.
bun run build:release

# Install
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 build/release/bun "$OUTPUT_DIR/usr/bin/bun"
ln -s bun "$OUTPUT_DIR/usr/bin/bunx"

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
