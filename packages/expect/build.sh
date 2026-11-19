#!/bin/sh
set -e

tar -xof expect5.45.4.tar.gz
cd expect5.45.4

# Tcl 9 port. Expect 5.45.4 (2018) is the last upstream release and has none, so
# this carries Debian's (40-tcl9, which builds against both Tcl 8.6 and 9.1), the
# three earlier Debian patches its context depends on (11, 13, 22), and 41 (fixes
# uninitialised variables the port's code paths reach). The LFS gcc 15 patch the
# recipe used to apply whole overlaps 40-tcl9, so only the part Debian does not
# already make is applied, last. Provenance and license are in each file's header.
#
# The digests cover every file the patches touch, before and after: a different
# expect source fails before patching, and a patch that applies differently
# (offset, fuzz, a hunk landing elsewhere) fails after it.
PATCHED="configure configure.in Dbg.c example/gethostbyaddr example/multixterm
  example/multixterm.man example/rftp exp_chan.c exp_clib.c exp_command.c exp_command.h
  exp_console.c exp_event.c exp_glob.c exp_int.h exp_inter.c exp_log.c exp_main_exp.c
  exp_main_sub.c exp_pty.c exp_trap.c exp_tty_in.h exp_tty.c exp_tty.h exp_win.c exp_win.h
  expect.c expect.h Makefile.in pty_termios.c retoglob.c"
check_tree() {
  got=$(sha256sum $PATCHED | sha256sum | cut -d' ' -f1)
  if [ "$got" != "$1" ]; then
    echo "expect: $2 sources digest $got, want $1" >&2
    sha256sum $PATCHED >&2
    exit 1
  fi
}

check_tree 87e3f77e60a274fe43b35780aaa15ffc043dead1588a6c51e9d437ecb49c2be7 unpatched
for p in debian-11-ttyname debian-13-implicit-defs debian-22-segfault-with-stubs \
         debian-40-tcl9 debian-41-uninitialized expect-5.45.4-gcc15-residual; do
  patch -Np1 --fuzz=0 -i ../$p.patch
done
check_tree 667df1d6b3e0c66140943f5b70741db7ce388787d99318e995d989cff9383ea5 patched

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3"; BUILD_TRIPLET="x86_64-unknown-linux-gnu" ;;
  aarch64) MARCH="-march=armv8-a";   BUILD_TRIPLET="aarch64-unknown-linux-gnu" ;;
  *)       MARCH="";                 BUILD_TRIPLET="$(uname -m)-unknown-linux-gnu" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# --with-tcl finds tcl's /usr/lib/tclConfig.sh, which names the Tcl it was built
# as (9.x); Debian's Makefile.in then names the library libtcl9expect<v>.so.
./configure  --prefix=/usr            \
            --build="$BUILD_TRIPLET" \
            --host="$BUILD_TRIPLET"  \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make -j$(nproc)
# make test # TODO has failures
make DESTDIR=$OUTPUT_DIR install

# `expect` links the library by its bare name and there is no rpath, so it has to
# be on the loader's path: link it into /usr/lib. Exactly one library, or fail.
set -- $OUTPUT_DIR/usr/lib/expect5.45.4/lib*expect5.45.4.so
[ $# -eq 1 ] && [ -f "$1" ] || { echo "expect: want one libexpect, got: $*" >&2; exit 1; }
ln -svf "expect5.45.4/${1##*/}" $OUTPUT_DIR/usr/lib
