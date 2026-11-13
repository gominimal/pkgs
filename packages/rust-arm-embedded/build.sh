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

# The -Zbuild-std rlibs (core, alloc, compiler_builtins, ...) are intermediate artifacts, so cargo
# keeps them in its build-dir, whose layout is internal and changed in cargo 1.100 (rust 1.100.0):
# target/<triple>/release/deps/ is gone, each unit now lives in build/<pkg>/<hash>/out/. Cargo's
# changelog points tools at its JSON messages instead, so ask cargo where it wrote each rlib:
# every compiler-artifact message lists the unit's output paths in "filenames". Rendered
# diagnostics still go to stderr; stdout carries only the JSON.
for target in $TARGETS; do
  cargo build -Zbuild-std=core,alloc --target "$target" --release \
    --message-format=json-render-diagnostics > "../artifacts-${target}.jsonl"
done

cd ..

# Install the built sysroot libraries
for target in $TARGETS; do
  DST="$OUTPUT_DIR/usr/lib/rustlib/${target}/lib"
  mkdir -p "$DST"
  # .rlib paths named by compiler-artifact messages (cargo's compact JSON, one message per line).
  # Only units built for $target: build scripts and host-side build deps sit outside its
  # <triple>/ dir. The dummy driver crate is skipped.
  RLIBS="$(grep '"reason":"compiler-artifact"' "artifacts-${target}.jsonl" \
    | grep -o '"filenames":\[[^]]*\]' | grep -o '"[^"]*\.rlib"' | tr -d '"' | sort -u)"
  n=0
  for f in $RLIBS; do
    case "$f" in */"${target}"/release/*) ;; *) continue ;; esac
    case "$(basename "$f")" in libdriver.rlib | libdriver-*) continue ;; esac
    cp "$f" "$DST/"
    n=$((n + 1))
  done
  # Positive control: if cargo's messages ever stop naming the std rlibs, fail here instead of
  # shipping an empty sysroot.
  for crate in core alloc compiler_builtins; do
    ls "$DST"/lib${crate}-*.rlib > /dev/null || { echo "rust-arm-embedded: FATAL no lib${crate}-*.rlib for ${target} (copied ${n} rlibs)" >&2; exit 1; }
  done
  echo "rust-arm-embedded: ${target}: ${n} rlibs"
done
