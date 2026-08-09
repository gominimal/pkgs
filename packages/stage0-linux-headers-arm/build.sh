#!/bin/sh
set -ex

tar -xof linux-6.12.43.tar.xz
cd linux-6.12.43
SRCDIR=$(pwd)

# `make headers` compiles exactly ONE thing with the host compiler: scripts/unifdef. Everything
# after that is sed/sh doing the UAPI export. So the only hazard is how unifdef gets built.
#
# THE HAZARD, measured here 2026-08-09:
#   scripts/unifdef.c:51 -> /usr/include/errno.h:28 -> /usr/include/bits/errno.h:26
#   fatal error: linux/errno.h: No such file or directory
# glibc's bits/errno.h includes <linux/errno.h> — the very headers this recipe produces. Building
# kernel headers needs kernel headers.
#
# The amd64 rung (stage0-linux-headers-6.12.43) solves this by pointing HOSTCC at a WRAPPER that
# uses a musl sysroot, whose errno.h does not chain into linux/. arm has no musl sysroot here, but
# it does not need one: THE KERNEL SOURCE ALREADY CONTAINS these headers at include/uapi, so the
# include can be satisfied from the tree we are about to install — identical content by
# construction, not a substitute pulled from the host.
#
# It must be delivered via a HOSTCC WRAPPER, not `make headers HOSTCFLAGS=...`. That was tried and
# the build failed identically: the kernel does not thread a HOSTCFLAGS set on the make line into
# the host-tool compile the way this needs. HOSTCC is the lever the amd64 rung uses, and it works.
GCCCC="$SRCDIR/gcc-cc"
cat > "$GCCCC" <<EOF
#!/bin/sh
exec /usr/bin/gcc -I$SRCDIR/include/uapi "\$@"
EOF
chmod +x "$GCCCC"

make HOSTCC="$GCCCC" headers

mkdir -p $OUTPUT_DIR/usr
cp -rv usr/include $OUTPUT_DIR/usr/
