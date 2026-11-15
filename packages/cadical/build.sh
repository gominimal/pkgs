#!/bin/sh
set -ex
export CXX=g++
export CXXFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
# 3.x also compiles one C file (src/kitten.c) with CC/CFLAGS (CC defaults to
# gcc for CXX=g++), so it gets the same reproducibility flags.
export CFLAGS="$CXXFLAGS"
export LDFLAGS="-Wl,--build-id=none"

# Reproducibility: scripts/make-build-header.sh writes build.hpp's DATE macro,
# which lands in .rodata. Since 3.0.0 it takes the date from SOURCE_DATE_EPOCH
# (set by the sandbox, AGENTS.md), but it still appends `uname -srmn`: the
# host's hostname and kernel release. Its other inputs are already
# deterministic here: the git id is empty (no .git in the tarball), COMPILER
# is `g++ --version`, FLAGS are the CXXFLAGS above.
# Rather than edit the upstream script, give the make step a pinned `uname`
# on PATH (kernel name and machine only, no hostname, no kernel release) and
# TZ=UTC so the epoch renders the same everywhere.
: "${SOURCE_DATE_EPOCH:?SOURCE_DATE_EPOCH unset}"
real_uname="$(command -v uname)"
shims="$(mktemp -d)"
cat > "$shims/uname" <<SHIM
#!/bin/sh
echo "\$("$real_uname" -s) \$("$real_uname" -m)"
SHIM
chmod 755 "$shims/uname"

./configure
PATH="$shims:$PATH" TZ=UTC make -j"$(nproc)" cadical

# Fail closed if the header carries anything but the pinned value: a future
# script change (dropping SOURCE_DATE_EPOCH, or no longer reading `uname` from
# PATH) would otherwise silently put host data back into the binary.
pinned="$(echo "$(LC_TIME=C TZ=UTC date -d "@$SOURCE_DATE_EPOCH") $("$shims/uname")" | sed -e 's,  *, ,g')"
grep -qxF "#define DATE \"$pinned\"" build/build.hpp || {
  echo "ERROR: build/build.hpp DATE is not the pinned value:" >&2
  grep '^#define DATE' build/build.hpp >&2 || true
  exit 1
}

mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/cadical "$OUTPUT_DIR/usr/bin/cadical"
