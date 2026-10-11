#!/bin/sh
set -ex

# CBMC's CMake fetches its SAT solvers at configure time (download_project).
# The sandbox has no network, so point those URLs at the tarballs this
# package already declares (extract = false; they land in the build cwd).
# The URL_MD5 / URL_HASH checks next to each URL stay in force.
here=$(pwd)
sed -i \
  -e "s|http://ftp.debian.org/debian/pool/main/m/minisat2/minisat2_2.2.1.orig.tar.gz|file://$here/minisat2_2.2.1.orig.tar.gz|" \
  -e "s|https://github.com/arminbiere/cadical/archive/rel-3.0.0.tar.gz|file://$here/rel-3.0.0.tar.gz|" \
  src/solvers/CMakeLists.txt
# Fail loudly if upstream moved a URL and the rewrite silently missed it.
! grep -nE "URL https?://" src/solvers/CMakeLists.txt | grep -E "minisat2_2.2.1|cadical/archive/rel-3.0.0"

# library_check.sh compiles CBMC's C library models with the host gcc under
# -Werror. gcc 15 declares the __atomic_* builtins with volatile pointer types,
# so the models' declarations trip builtin-declaration-mismatch. Demote only
# that warning; every other warning stays fatal, so the check still runs.
sed -i 's|\$CC -S -Wall -Werror |$CC -S -Wall -Werror -Wno-error=builtin-declaration-mismatch |' \
  src/ansi-c/library_check.sh
grep -q 'Wno-error=builtin-declaration-mismatch' src/ansi-c/library_check.sh

export CFLAGS="-O2 -ffile-prefix-map=$here=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

# The solver set upstream's release packages use. JBMC (the Java front end)
# needs a JDK and Maven and is not what Kani uses.
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -Dsat_impl="minisat2;cadical" \
  -DWITH_JBMC=OFF \
  -Denable_cbmc_tests=OFF
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
# A helper script with a `#!/usr/bin/env python` shebang; nothing Kani or the
# cbmc binaries use, and it would drag python into runtime_deps.
rm "$OUTPUT_DIR/usr/bin/ls_parse.py"
