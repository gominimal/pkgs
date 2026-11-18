#!/bin/sh
set -e

# cmake/Install.cmake's fish_try_create_dirs calls `install(SCRIPT CODE "...")`:
# SCRIPT takes a file and CODE is its own keyword, so SCRIPT has no value.
# CMake before 4.5 ignored that; 4.5 fails configure with "install SCRIPT given
# invalid argument: SCRIPT: missing required value" (pkgs#1526). `install(CODE
# "...")` is what it means and does the same on every CMake. Still on fish
# master as of 2026-11-15. sed is silent on a miss, so check after.
sed -i 's/install(SCRIPT CODE "/install(CODE "/' cmake/Install.cmake
if grep -n 'install(SCRIPT CODE' cmake/Install.cmake; then
  echo "fish: install(SCRIPT CODE) fix did not apply" >&2
  exit 1
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

# Cargo.lock takes fluent-ftl-tools as a git dependency from codeberg.org, which
# dropped out of the .org zone on 2026-11-18 (NXDOMAIN at the registry) and failed
# the build ("failed to resolve address for codeberg.org"). Fetch it from the
# author's GitHub copy instead: git's insteadOf rewrites only the URL, and cargo
# still checks out the commit Cargo.lock pins (5917664c), so the source is the
# same. Cargo's built-in git client ignores insteadOf, hence the git CLI.
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=url.https://github.com/danielrainer/fluent-ftl-tools.insteadOf
export GIT_CONFIG_VALUE_0=https://codeberg.org/danielrainer/fluent-ftl-tools

cmake -D CMAKE_INSTALL_PREFIX=/usr       \
      -D CMAKE_BUILD_TYPE=Release        \
      -D FISH_USE_SYSTEM_PCRE2=ON        \
      -D WITH_DOCS=OFF                   \
      -G Ninja ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
