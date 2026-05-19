#!/bin/sh
set -e

# Hermetic build path: when /cargo-vendor exists, configure cargo to
# resolve crates from there before invoking cmake (which transitively
# runs cargo). The config lives in the source root (one level up from
# the cmake build dir) so cargo finds it when cmake calls it.
if [ -d /cargo-vendor ]; then
    # fish's Cargo.toml has a git-source dep on
    # github.com/fish-shell/rust-pcre2 (a UTF-32 fork of pcre2 not
    # available on crates.io). cargo vendor packs those crates into
    # vendor/ alongside crates-io deps but cargo's offline resolver
    # needs an explicit [source."git+<url>?tag=<tag>"] entry to find
    # them. Without this, the build fails with: "can't checkout from
    # 'https://github.com/fish-shell/rust-pcre2': offline mode".
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source."git+https://github.com/fish-shell/rust-pcre2?tag=0.2.9-utf32"]
git = "https://github.com/fish-shell/rust-pcre2"
tag = "0.2.9-utf32"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    export CARGO_NET_OFFLINE=true
fi

mkdir build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Cargo build scripts expect 'cc'; create symlink to gcc
mkdir -p /tmp/bin
ln -sf "$(command -v gcc)" /tmp/bin/cc
export PATH="/tmp/bin:$PATH"

cmake -D CMAKE_INSTALL_PREFIX=/usr       \
      -D CMAKE_BUILD_TYPE=Release        \
      -D FISH_USE_SYSTEM_PCRE2=ON        \
      -D WITH_DOCS=OFF                   \
      -G Ninja ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
