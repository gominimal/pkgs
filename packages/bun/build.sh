#!/bin/sh
set -ex

# Extract and set up bootstrap bun binary
case $(uname -m) in
  x86_64)  BUN_ARCH=x64;   CARGO_TARGET=x86_64-unknown-linux-gnu ;;
  aarch64) BUN_ARCH=aarch64; CARGO_TARGET=aarch64-unknown-linux-gnu ;;
esac
python3 -m zipfile -e "bun-linux-${BUN_ARCH}.zip" .
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

# Remove rust-toolchain.toml to avoid rustup nightly requirement;
# our stable rust is sufficient for lol-html
rm -f rust-toolchain.toml

# Initialize a git repo so CMake's dependency version generation works
# (it runs "git rev-parse HEAD" to get version strings for bundled packages)
git init -q
git -c user.email=build@local -c user.name=build commit -q -m "v1.3.10" --allow-empty

# Install npm dependencies and generate source file lists
bun install --frozen-lockfile
bun run glob-sources

# Configure with CMake
cmake -GNinja -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DENABLE_BASELINE=OFF \
  -DENABLE_LTO=OFF \
  -DENABLE_ASAN=OFF \
  -DUSE_STATIC_LIBATOMIC=OFF \
  -Wno-dev

# Build
ninja -C build bun

# Install
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 build/bun "$OUTPUT_DIR/usr/bin/bun"
ln -s bun "$OUTPUT_DIR/usr/bin/bunx"
