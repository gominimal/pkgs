#!/bin/sh
set -e

# Security backport (see build.ncl). `set -e` plus patch's non-zero exit on a
# rejected hunk means a stale patch ABORTS the build rather than silently
# shipping an unpatched libasound.
patch -Np1 -i "CVE-2026-90781-numid.patch"   # control/ctlparse.c  numid= one-byte stack overrun (1e27d63e)
patch -Np1 -i "CVE-2026-90781.patch"         # control/ctlparse.c  name= one-byte stack overruns (f84cd4ce)

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make check

# Regression test for CVE-2026-90781. The overrun is a single '\0' written one
# byte past a stack array, which corrupts nothing observable on its own, so the
# test compiles ctlparse.c itself under AddressSanitizer (the copy inside
# libasound.so is not instrumented) and parses element ids that hit each of
# the three copy loops with 100 characters: a quoted name, an unquoted name,
# and a numid. Unpatched, ASan reports stack-buffer-overflow and the build
# fails; patched, each copy stops in bounds. Built in a scratch dir, never
# installed.
mkdir -p cve-test
cat > cve-test/ctlparse_overrun.c <<'EOF'
#include "../src/control/ctlparse.c"
#include <stdio.h>
#include <string.h>

static int parse(const char *s)
{
	snd_ctl_elem_id_t *id;
	snd_ctl_elem_id_alloca(&id);
	int err = snd_ctl_ascii_elem_id_parse(id, s);
	printf("parse(%zu chars) = %d, name length %zu\n",
	       strlen(s), err, strlen(snd_ctl_elem_id_get_name(id)));
	return err;
}

int main(void)
{
	char quoted[128] = "name='", unquoted[128] = "name=", numid[128] = "numid=";
	memset(quoted + 6, 'A', 100);
	strcpy(quoted + 106, "'");
	memset(unquoted + 5, 'B', 100);
	unquoted[105] = '\0';
	memset(numid + 6, '1', 100);
	numid[106] = '\0';
	if (parse(quoted) < 0 || parse(unquoted) < 0)
		return 1;
	/* A 100-digit numid is out of range, so the parse is rejected. What
	 * matters is that the copy into buf stayed in bounds getting there. */
	if (parse(numid) >= 0)
		return 1;
	return 0;
}
EOF
gcc -O1 -g -fsanitize=address -fno-omit-frame-pointer \
    -I include -I src/control \
    -o cve-test/ctlparse_overrun cve-test/ctlparse_overrun.c \
    -L src/.libs -lasound
ASAN_OPTIONS=detect_leaks=0:abort_on_error=0 \
  LD_LIBRARY_PATH="$(pwd)/src/.libs" ./cve-test/ctlparse_overrun

make DESTDIR=$OUTPUT_DIR install
