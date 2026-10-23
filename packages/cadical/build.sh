#!/bin/sh
set -ex
export CXX=g++
export CXXFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"

# Reproducibility: scripts/make-build-header.sh (unchanged through 2.1.3) puts
# `date` and `uname -srmn` into build.hpp's DATE macro, which lands in .rodata:
# the build's wall clock plus the host's hostname and kernel release. Its other
# inputs are already deterministic here: the git id is empty (no .git in the
# tarball), COMPILER is `g++ --version`, FLAGS are the CXXFLAGS above.
# Rather than edit the upstream script, give it pinned `date` and `uname` on
# PATH for the make step only:
#   date  -> the sandbox's SOURCE_DATE_EPOCH (AGENTS.md), in UTC
#   uname -> kernel name and machine only (no hostname, no kernel release)
real_date="$(command -v date)"
real_uname="$(command -v uname)"
shims="$(mktemp -d)"
cat > "$shims/date" <<EOF
#!/bin/sh
exec "$real_date" -u -d "@\${SOURCE_DATE_EPOCH:?SOURCE_DATE_EPOCH unset}" "\$@"
EOF
cat > "$shims/uname" <<EOF
#!/bin/sh
echo "\$("$real_uname" -s) \$("$real_uname" -m)"
EOF
chmod 755 "$shims/date" "$shims/uname"

./configure
PATH="$shims:$PATH" make -j"$(nproc)" cadical

# Fail closed if the header still carries host data (a future script change
# that stops reading `date`/`uname` from PATH would otherwise slip through).
pinned="$(echo "$("$shims/date") $("$shims/uname")" | sed -e 's,  *, ,g')"
grep -qxF "#define DATE \"$pinned\"" build/build.hpp || {
  echo "ERROR: build/build.hpp DATE is not the pinned value:" >&2
  grep '^#define DATE' build/build.hpp >&2 || true
  exit 1
}

mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/cadical "$OUTPUT_DIR/usr/bin/cadical"
