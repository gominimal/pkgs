#!/bin/sh
set -ex

ABI="$MINIMAL_ARG_ABI"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

CFLAGS="$MARCH -O2 -pipe -fPIC -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"

# LUA_USE_POSIX + LUA_USE_DLOPEN is what LUA_USE_LINUX expands to minus
# readline, which only the standalone interpreter needs -- this package ships
# the library, so it stays out of the dependency set. `ar -D` for a
# deterministic archive.
make -C src liblua.a \
  CC=gcc \
  AR="ar -D rc" \
  MYCFLAGS="$CFLAGS -DLUA_USE_POSIX -DLUA_USE_DLOPEN"

# Upstream ships no shared library and no rule to build one; every distro links
# its own. The SONAME is the versioned name so `-llua5.4` records a series-
# specific dependency and the four series coexist.
gcc -shared -Wl,-soname,"liblua$ABI.so" -Wl,--build-id=none \
  -o "liblua$ABI.so" src/*.o -lm -ldl

install -D -m 0644 src/liblua.a     "$OUTPUT_DIR/usr/lib/liblua$ABI.a"
install -D -m 0755 "liblua$ABI.so"  "$OUTPUT_DIR/usr/lib/liblua$ABI.so"

# Headers go under a versioned directory so the series can be installed
# together without fighting over usr/include/lua.h.
mkdir -p "$OUTPUT_DIR/usr/include/lua$ABI"
install -m 0644 src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h \
  "$OUTPUT_DIR/usr/include/lua$ABI/"

# The C++ wrapper header arrived in 5.2; 5.1 has no lua.hpp to install.
if [ -f src/lua.hpp ]; then
  install -m 0644 src/lua.hpp "$OUTPUT_DIR/usr/include/lua$ABI/"
fi
