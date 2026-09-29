#!/usr/bin/env bash
# stage0-binutils-2.30: builds binutils 2.30 (as, ld, ar, nm, objcopy, objdump, strip, ranlib,
# libbfd.a, libopcodes.a) from binutils-2.30.tar.xz with tcc-musl2 as CC, linked statically against
# the musl sysroot at /usr/lib/musl-bedrock, installed under /usr into $OUTPUT_DIR. The tarball ships
# every generated file; nothing is regenerated (no autoreconf/bison/flex/perl here).
# phases: unpack, CC wrapper, per-subdir configure, build, install, triplet symlinks, pin gate
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.30}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
T="x86_64-linux-gnu"   # build=host=target

# --- unpack ---
# --no-same-owner: the sandbox user namespace cannot chown to the archived uid.
tar --no-same-owner -xf "${SRC}.tar.xz"
cd "${SRC}"

# No source preparation: every shipped generated file (configure, Makefile.in, the bison/flex .c
# files, opcodes/i386-tbl.h, i386-init.h) is used as is. The three .patch files in this directory
# belong to the regenerating build path and are intentionally not applied. -DDYNAMIC_CRC_TABLE=1
# builds the crc32 table at runtime, so no static table needs regenerating.

# --- CC wrapper over tcc-musl2 ---
# Compile (-c/-S/-E) passes straight through. Link puts the crt files explicitly and libc.a on both
# sides of libtcc1.a: libtcc1 references abort() in libc, and a single -lc leaves that cycle
# unresolved on a static link. tcc -ar is used directly for archives.
cat > "${BUILDROOT}/musl-cc" <<'WRAP'
#!/bin/sh
# Build against the single-writer musl sysroot, not /usr: the sandbox rootfs merges a glibc whose
# usr/include and usr/lib/libc.a can shadow musl's. -nostdinc plus explicit crt/libc from $MB make
# every compile and link deterministic. /usr/lib/tcc/libtcc1.a has a single writer.
MB=/usr/lib/musl-bedrock
for a in "$@"; do case "$a" in -c|-S|-E) exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" "$@" ;; esac; done
exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" -nostdlib -static \
  "$MB/lib/crt1.o" "$MB/lib/crti.o" "$@" \
  "$MB/lib/libc.a" /usr/lib/tcc/libtcc1.a "$MB/lib/libc.a" "$MB/lib/crtn.o"
WRAP
chmod +x "${BUILDROOT}/musl-cc"
MUSLTCC="${BUILDROOT}/musl-cc"

# --- configure each subdir in dependency order ---
for dir in intl libiberty opcodes bfd binutils gas gprof ld zlib; do
  ( cd "$dir" && \
    LD="true" AR="/usr/bin/tcc-musl2 -ar" CC="${MUSLTCC}" \
      CFLAGS="-DBUILDFIXED=1 -DDYNAMIC_CRC_TABLE=1" \
      ./configure \
        --disable-nls \
        --enable-deterministic-archives \
        --enable-64-bit-bfd \
        --build="${T}" --host="${T}" --target="${T}" \
        --program-prefix="" \
        --prefix=/usr \
        --libdir=/usr/lib \
        --with-sysroot= \
        --srcdir=. \
        --enable-compressed-debug-sections=all \
        lt_cv_sys_max_cmd_len=32768 )
done

# --- build: bfd headers first, then per dir ---
make -C bfd headers
for dir in libiberty zlib bfd opcodes binutils gas gprof ld; do
  make -C "$dir" tooldir=/usr CPPFLAGS="-DPLUGIN_LITTLE_ENDIAN" MAKEINFO=true
done

# --- install + triplet symlinks ---
for dir in libiberty zlib bfd opcodes binutils gas gprof ld; do
  make -C "$dir" tooldir=/usr DESTDIR="${OUTPUT_DIR}" install MAKEINFO=true
done
cd "${OUTPUT_DIR}/usr/bin"
# Relative symlinks: an absolute /usr/bin/$f target dangles inside $OUTPUT_DIR at staging time.
# -f for idempotence; skip already-prefixed names so the glob cannot nest.
for f in *; do
  case "$f" in x86_64-linux-musl-*) continue ;; esac
  ln -sf "$f" "x86_64-linux-musl-$f"
done

# --- pin gate: disabled until stage0.answers carries the captured shas ---
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
