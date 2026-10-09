#!/bin/sh
# Build Verus (rust_verify + vstd) offline and install it as a self-contained
# tree at /usr/lib/verus:
#
#   verus, rust_verify, cargo-verus, libvstd.rlib, vstd.vir, builtin libs ...
#   toolchain/   Rust 1.98.1 WITH rustc-dev (rust_verify is a rustc driver),
#                private so it never shadows the system rust
#
# /usr/bin/verus and /usr/bin/cargo-verus are wrappers: VERUS_USE_RUSTUP=0
# (no rustup in Minimal), VERUS_Z3_PATH at the pinned z3-4.16.0, and the
# toolchain's lib on LD_LIBRARY_PATH for rust_verify.
set -eu
version="$MINIMAL_ARG_VERSION"
sha="$MINIMAL_ARG_SHA"
rust="$MINIMAL_ARG_RUST"
SRCROOT=$(pwd)
VDIR="$OUTPUT_DIR/usr/lib/verus"
TC="$VDIR/toolchain"

# 1. The toolchain, from the official component tarballs (extract = false).
mkdir -p "$TC" /tmp/verus-tc
for f in *-"$rust"-*.tar.xz; do
  tar -xof "$f" -C /tmp/verus-tc
done
for inst in /tmp/verus-tc/*/install.sh; do
  ( cd "$(dirname "$inst")" && ./install.sh --prefix="$TC" --disable-ldconfig )
done
for f in "$TC"/lib/rustlib/manifest-* "$TC"/lib/rustlib/install.log \
         "$TC"/lib/rustlib/rust-installer-version "$TC"/lib/rustlib/uninstall.sh \
         "$TC"/bin/rust-gdb "$TC"/bin/rust-gdbgui "$TC"/bin/rust-lldb; do
  if [ -e "$f" ]; then rm "$f"; fi
done
# rustc-dev's second librustc_driver (lib/rustlib/<target>/lib) is what
# LD_LIBRARY_PATH-loaded build scripts pick up; its $ORIGIN/../lib has no
# libLLVM in a private prefix. Same fix as packages/kani.
for d in "$TC"/lib/rustlib/*/lib; do
  [ -e "$d"/librustc_driver-*.so ] || continue
  for llvm in "$TC"/lib/libLLVM*; do
    ln -s "../../../$(basename "$llvm")" "$d/$(basename "$llvm")"
  done
done
export PATH="$TC/bin:$PATH"

cd source

# 2. Offline crates.
tar -xof "$SRCROOT/verus-vendor-$version.tar.gz"
cat >> .cargo/config.toml <<'CFG'

[source.crates-io]
replace-with = "vendored-sources"

[source."git+https://github.com/utaal/getopts.git?branch=parse-partial"]
git = "https://github.com/utaal/getopts.git"
branch = "parse-partial"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CFG
# Reproducibility: extend the config's own rustflags list (RUSTFLAGS would
# replace it, dropping Verus's required --cfg flags).
sed -i "s|^rustflags = \[|rustflags = [ \"--remap-path-prefix=$SRCROOT=/builddir\",|" .cargo/config.toml
grep -q "remap-path-prefix=$SRCROOT" .cargo/config.toml

# 3. Verus's build scripts read version info from git unconditionally
#    (cargo-verus-toolchains/src/versions.rs). Give them a throwaway repo with
#    fixed dates; the real version, sha and toolchain are pinned through
#    Verus's own VARGO_BUILD_* / VARGO_TOOLCHAIN overrides.
git init -q .
git add -A
GIT_AUTHOR_NAME=minimal GIT_AUTHOR_EMAIL=build@minimal.dev \
GIT_COMMITTER_NAME=minimal GIT_COMMITTER_EMAIL=build@minimal.dev \
GIT_AUTHOR_DATE="2026-10-04T00:00:00Z" GIT_COMMITTER_DATE="2026-10-04T00:00:00Z" \
  git commit -q -m "verus $version"
export VARGO_BUILD_VERSION="$version"
export VARGO_BUILD_SHA="$sha"
case "$(uname -m)" in
  x86_64)  triple=x86_64-unknown-linux-gnu ;;
  aarch64) triple=aarch64-unknown-linux-gnu ;;
esac
export VARGO_TOOLCHAIN="$rust-$triple"
export VERUS_USE_RUSTUP=0
# verus/build.rs runs `rustup show active-toolchain` unconditionally, only to
# embed the toolchain NAME (used for `rustup run`, which VERUS_USE_RUSTUP=0
# skips). A build-time shim answers that one query; it is not installed.
mkdir -p /tmp/verus-shim
cat > /tmp/verus-shim/rustup <<'SHIM'
#!/bin/sh
if [ "$1 $2" = "show active-toolchain" ]; then
  echo "$VARGO_TOOLCHAIN (default)"
  exit 0
fi
echo "rustup shim: unsupported: $*" >&2
exit 1
SHIM
chmod 755 /tmp/verus-shim/rustup
export PATH="/tmp/verus-shim:$PATH"

export CARGO_HOME="$SRCROOT/.cargo-home"
export CARGO_NET_OFFLINE=true
export CC=gcc
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=gcc
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=gcc
# rust_verify links librustc_driver dynamically; when cargo-verus runs it to
# verify vstd, it must find the private toolchain's libs.
export LD_LIBRARY_PATH="$TC/lib"

# vstd is VERIFIED during the build, with z3 at source/z3 (.cargo/config.toml).
ln -s "$(command -v "z3-$MINIMAL_ARG_Z3")" z3

# 4. Upstream's "Build with Cargo" steps (BUILD.md).
# tools/bump_crate_versions is a maintainers' crate-publishing tool and the only
# member that pulls in openssl-sys; nothing installed depends on it.
cargo build --release --workspace --exclude bump_crate_versions
cargo run --release -p cargo-verus -- build --release --manifest-path vstd/Cargo.toml

mkdir -p "$VDIR"
cp -R target-verus/release/. "$VDIR/"

# 5. PATH wrappers.
mkdir -p "$OUTPUT_DIR/usr/bin"
for b in verus cargo-verus; do
  cat > "$OUTPUT_DIR/usr/bin/$b" <<WRAP
#!/bin/sh
export VERUS_USE_RUSTUP=0
export VERUS_Z3_PATH="\${VERUS_Z3_PATH:-/usr/bin/z3-$MINIMAL_ARG_Z3}"
export LD_LIBRARY_PATH="/usr/lib/verus/toolchain/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export PATH="/usr/lib/verus/toolchain/bin:\$PATH"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="\${CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER:-gcc}"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="\${CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER:-gcc}"
exec /usr/lib/verus/$b "\$@"
WRAP
  chmod 755 "$OUTPUT_DIR/usr/bin/$b"
done
