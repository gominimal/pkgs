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

# Offline -Zbuild-std: cargo resolves std's OWN external deps (cfg-if, libc,
# hashbrown, compiler_builtins, …) from the locked rust-src library/Cargo.lock.
# crates.io is unavailable in CS, so the cargo_vendor input ships those deps
# pre-vendored (`cargo vendor` of rustc-1.95.0-src/library, sha-matched to the
# builder's rust-src lock) and the builder hydrates them to /cargo-vendor. Point
# cargo there via a source replacement. CARGO_NET_OFFLINE stops the index fetch.
# (#55: rust-src ships only library/Cargo.lock, NO vendor dir — verified.)
# Mechanism validated locally end-to-end: offline -Zbuild-std=core,alloc for
# thumbv7em-none-eabi compiles compiler_builtins+core+alloc from the vendor.
export CARGO_NET_OFFLINE=true

# Verify rust-src is available in the sysroot
SYSROOT=$(rustc --print sysroot)
ls "${SYSROOT}/lib/rustlib/src/rust/library/core/Cargo.toml"

# Create a minimal no_std project to drive the build
mkdir -p driver/src driver/.cargo
cat > driver/Cargo.toml << 'EOF'
[package]
name = "driver"
version = "0.0.0"
edition = "2021"
EOF
echo '#![no_std] #![no_main]' > driver/src/lib.rs

# Redirect crates-io to the vendored std deps (offline CS path). Outside CS
# there's no /cargo-vendor, so the default registry is left in place.
if [ -d /cargo-vendor ]; then
  echo "=[rustarm]= vendored std deps: /cargo-vendor ($(ls /cargo-vendor 2>/dev/null | wc -l) crates)"
  cat > driver/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = "vendored-std"

[source.vendored-std]
directory = "/cargo-vendor"
EOF
fi

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
