#!/bin/sh
set -ex

export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

mkdir -p _build && cd _build

# WITHOUT_SERVER is the whole point: it drops mysqld, every storage engine and
# the embedded server, leaving the client programs and libmariadb. Building the
# server would add hundreds of MB that nothing in the agentbox runs.
#
# The plugins are disabled explicitly rather than relying on WITHOUT_SERVER —
# some auth/connect plugins still get configured in client-only builds and drag
# in dependencies (krb5, libxml2, unixODBC) we do not ship.
cmake .. -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DWITHOUT_SERVER=ON \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_SSL=system \
  -DWITH_ZLIB=system \
  -DPLUGIN_AUTH_GSSAPI=NO \
  -DPLUGIN_AUTH_GSSAPI_CLIENT=OFF \
  -DPLUGIN_CONNECT=NO \
  -DPLUGIN_MROONGA=NO \
  -DPLUGIN_ROCKSDB=NO \
  -DPLUGIN_SPIDER=NO \
  -DPLUGIN_TOKUDB=NO

make -j"$(nproc)"
make install DESTDIR="$OUTPUT_DIR"

# Fail closed on the binary the package exists for. A client-only cmake run
# that silently produced no CLI would otherwise ship an empty package that
# still satisfies the dependency.
if [ ! -x "$OUTPUT_DIR/usr/bin/mariadb" ]; then
  echo "mariadb: client binary was not produced" >&2
  exit 1
fi

# The test suite is large and meaningless without mysqld; drop it if the
# client-only build installed it anyway.
for d in "$OUTPUT_DIR/usr/mysql-test" "$OUTPUT_DIR/usr/share/mysql-test"; do
  [ -d "$d" ] && rm -r "$d"
done
exit 0
