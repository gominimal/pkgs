#!/bin/sh
set -ex

export CC=gcc
export CXX=g++

# Create cc/c++ symlinks (sandbox lacks them)
mkdir -p .local/bin
ln -s "$(command -v gcc)" .local/bin/cc
ln -s "$(command -v g++)" .local/bin/c++
export PATH="$(pwd)/.local/bin:$PATH"

# Allow -Zbuild-std on stable channel
export RUSTC_BOOTSTRAP=1

# Verify rust-src is available in the sysroot
SYSROOT=$(rustc --print sysroot)
ls "${SYSROOT}/lib/rustlib/src/rust/library/core/Cargo.toml"

# Create a minimal no_std project to drive the build
mkdir -p driver/src
cat > driver/Cargo.toml << 'EOF'
[package]
name = "driver"
version = "0.0.0"
edition = "2021"
EOF
echo '#![no_std] #![no_main]' > driver/src/lib.rs

cd driver

TARGETS="thumbv6m-none-eabi thumbv7em-none-eabi thumbv7em-none-eabihf"

for target in $TARGETS; do
  cargo build -Zbuild-std=core,alloc --target "$target" --release
done

cd ..

# Install the built sysroot libraries
# cargo -Zbuild-std places the compiled rlibs alongside the build artifacts
for target in $TARGETS; do
  SRC="driver/target/${target}/release/deps"
  DST="$OUTPUT_DIR/usr/lib/rustlib/${target}/lib"
  mkdir -p "$DST"
  # Copy standard library rlibs (exclude the dummy driver crate)
  for f in "$SRC"/lib*.rlib; do
    case "$(basename "$f")" in libdriver-*) continue ;; esac
    cp "$f" "$DST/"
  done
done
