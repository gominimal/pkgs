#!/bin/sh
set -ex

export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# plugin/auth_ed25519/CMakeLists.txt calls ADD_CONVENIENCE_LIBRARY(ref10 ...)
# UNCONDITIONALLY — outside the MYSQL_ADD_PLUGIN guard — so -DPLUGIN_AUTH_ED25519=NO
# disables the plugin but ref10 still compiles, and its sources pull in
# mysql/service_sha2.h. That header exists at include/mysql/service_sha2.h in
# the source tree; a client-only configure just does not add that include dir.
# So this is an include-path gap, not a plugin that needs disabling.
SRC="$(pwd)"
export CFLAGS="$CFLAGS -I$SRC/include"
export CXXFLAGS="$CXXFLAGS -I$SRC/include"

# Define HAVE_CURSES_H ourselves: MariaDB's cmake never sets it, and client/mysql.cc
# needs it. The file guards its curses include on
#     #if defined(HAVE_CURSES_H) && defined(HAVE_TERM_H)   (mysql.cc:64)
# but cmake/readline.cmake only ever defines HAVE_TERM_H (via CHECK_INCLUDE_FILES
# "curses.h;term.h") and CURSES_HAVE_CURSES_H — the latter being cmake's own
# FindCurses output variable, a DIFFERENT name that never reaches config.h. So
# HAVE_CURSES_H is referenced in exactly one file and defined in none, curses.h is
# never included, and every curses name in the file is undeclared:
#     mysql.cc:201: error: 'chtype' was not declared in this scope
#     mysql.cc:5334: error: 'A_BOLD' / mysql.cc:5505: error: 'setupterm'
# Meanwhile HAVE_VIDATTR *is* defined, because CHECK_LIBRARY_EXISTS finds vidattr in
# libncursesw — so the two halves of the same feature test disagree, and the half
# that compiles the code is the one that loses. Both headers are present here
# (/usr/include/curses.h, /usr/include/term.h; ncurses is already a build dep for
# the readline/CURSES_NEED_WIDE path above), so defining it is correct, not a
# workaround. Not passed via -DCMAKE_CXX_FLAGS because that would override rather
# than extend the flags set at the top of this file.
export CFLAGS="$CFLAGS -DHAVE_CURSES_H=1"
export CXXFLAGS="$CXXFLAGS -DHAVE_CURSES_H=1"

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
  -DWITH_READLINE=ON \
  \
  `# Our ncurses ships ONLY the wide build (libncursesw.so; there is no plain` \
  `# libncurses.so), and cmake's FindCurses does not look for the wide variant` \
  `# unless CURSES_NEED_WIDE is set — it fails with "Could NOT find Curses` \
  `# (missing: CURSES_LIBRARY)". The explicit paths are belt-and-braces for` \
  `# older FindCurses modules that ignore the flag.` \
  -DCURSES_NEED_WIDE=TRUE \
  -DCURSES_LIBRARY=/usr/lib/libncursesw.so \
  -DCURSES_INCLUDE_PATH=/usr/include \
  -DWITH_ZLIB=system \
  -DPLUGIN_AUTH_GSSAPI=NO \
  -DPLUGIN_AUTH_GSSAPI_CLIENT=OFF \
  -DPLUGIN_CONNECT=NO \
  -DPLUGIN_MROONGA=NO \
  -DPLUGIN_ROCKSDB=NO \
  -DPLUGIN_SPIDER=NO \
  -DPLUGIN_TOKUDB=NO \
  `# auth_ed25519 is the SERVER-side plugin and still gets configured in a` \
  `# client-only build; it includes mysql/service_sha2.h, which only exists in` \
  `# the server tree, so make dies with "No such file or directory". The` \
  `# client half of ed25519 auth is a separate target and is unaffected.` \
  -DPLUGIN_AUTH_ED25519=NO

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

# WITHOUT_SERVER drops mysqld but still installs the server-ADMINISTRATION
# helper scripts, which are Perl. Every one of them operates on a local server:
# its data directory (hotcopy), its grant tables (access, setpermission), its
# slow-query log (dumpslow), or its initial setup (secure-installation). None of
# them can do anything in a package that ships no server.
#
# Keeping them would mean adding perl to runtime_deps to satisfy the
# missing-runtime_deps checker — pulling a language runtime into the closure of
# a client package purely to carry scripts that cannot run. Dropping them is the
# honest fix, and it is the same call the mysql-test removal above makes.
#
# Deliberately KEPT: mysql_config / mariadb_config. Those report the compile and
# link flags for building against libmariadb, which this package does ship (see
# the `libs` output), so they are client tools, not server tools. They are
# /bin/sh scripts, which is why bash is a runtime dep.
for s in access convert-table-format dumpslow find-rows hotcopy \
         secure-installation setpermission; do
  rm -f "$OUTPUT_DIR/usr/bin/mariadb-$s"
done
for s in mysqlaccess mysql_convert_table_format mysqldumpslow mysql_find_rows \
         mysqlhotcopy mysql_secure_installation mysql_setpermission \
         msql2mysql mytop; do
  rm -f "$OUTPUT_DIR/usr/bin/$s"
done

# Fail closed: if upstream renames these, the loop above silently removes
# nothing and perl creeps back into the closure. Assert no interpreted script
# survives except the *_config pair we keep on purpose.
leftover=$(grep -lE '^#!.*(perl|/bin/sh|/usr/bin/env)' "$OUTPUT_DIR"/usr/bin/* 2>/dev/null \
  | grep -vE '/(mysql_config|mariadb_config)$' || true)
if [ -n "$leftover" ]; then
  echo "mariadb: unexpected interpreted scripts still installed:" >&2
  echo "$leftover" >&2
  exit 1
fi
exit 0
