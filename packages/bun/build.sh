#!/bin/sh
set -ex

# Provide an `unzip` shim backed by python's zipfile module (no unzip package
# in the minimal environment). The nested build calls `unzip -o -DD -d <dest>
# <zip>` to extract the downloaded zig toolchain.
mkdir -p shims
cat > shims/unzip <<'SHIM'
#!/usr/bin/env python3
import sys, os, zipfile
args = sys.argv[1:]
dest, src = ".", None
i = 0
while i < len(args):
    a = args[i]
    if a in ("-o", "-DD", "-q", "-qq"):
        i += 1
    elif a == "-d":
        dest = args[i + 1]; i += 2
    else:
        src = a; i += 1
if src is None:
    sys.exit("unzip shim: missing zip path")
os.makedirs(dest, exist_ok=True)
with zipfile.ZipFile(src) as z:
    z.extractall(dest)
    for info in z.infolist():
        if info.external_attr:
            mode = (info.external_attr >> 16) & 0o777
            if mode:
                os.chmod(os.path.join(dest, info.filename), mode)
SHIM
chmod +x shims/unzip
export PATH="$(pwd)/shims:$PATH"

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
