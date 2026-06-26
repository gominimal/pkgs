#!/bin/sh
# build.sh — R5 (stage0-binutils-2.30) driver. SKELETON / WIP 2026-06-26.
# Model-B adaptation of live-bootstrap steps/binutils-2.30/pass1.sh: ship ALL generated files, skip the
# autoreconf/bison/flex/perl regen (none exist in bedrock). First rung to LINK executables (as/ld/ar/nm/
# objcopy/objdump/strip) against R4's musl. CC = R3 tcc-0.9.27.
#
# ############################################################################################
# ## ⚠️ UNRESOLVED WALL — the tcc↔musl link bridge (see .staging-ctx/bedrock-R5-binutils-status). ##
# ## R3 tcc bakes CRTPREFIX=/usr/lib/mes (mes), but binutils must link against MUSL at /usr/lib.   ##
# ## /usr is read-only and tcc-0.9.27 has no runtime CRTPREFIX override, so `CC=tcc` alone links   ##
# ## MES (too minimal for binutils). live-bootstrap's answer = a tcc PASS2 rebuilt against musl.   ##
# ## PLUS a possible GOTPCREL static-linker crash (musl-crt-diag v23 canary decides real-vs-emul). ##
# ## => CC below is a PLACEHOLDER: replace with the musl-relinked tcc once that precursor lands.    ##
# ############################################################################################
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.30}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
T="x86_64-linux-gnu"   # build=host=target; shipped 2018 config.sub resolves -gnu AND -musl (no donor swap)

# --- unpack (.tar.xz -> needs xz in the closure) ---
tar -xf "${SRC}.tar.xz"
cd "${SRC}"

# --- Model-B: NO src_prepare regen. We deliberately KEEP every shipped generated file (configure,
#     Makefile.in, the 11 bison/flex .c, opcodes/i386-tbl.h + i386-init.h, bfd headers). The 3 upstream
#     patches are all Model-A-only NO-OPs (carried in the pkg dir + build.ncl, intentionally NOT applied):
#       libiberty-add-missing-config-directory-reference / new-gettext / opcodes-ensure-i386-init-deps.
#     crc32 static-table regen is unneeded: CFLAGS carries -DDYNAMIC_CRC_TABLE=1 (runtime gen). ---

# TODO(WALL): produce a musl-linked tcc here (recompile tcc.c with -D CONFIG_TCC_CRTPREFIX="/usr/lib"
#   -D CONFIG_TCC_SYSINCLUDEPATHS="/usr/include" -D TCC_LIBGCC="/usr/lib/libc.a" using R3 tcc + R4 musl),
#   install it as $BUILDROOT/musl-tcc, and set CC accordingly. Until then this is a stub.
MUSLTCC="tcc"   # PLACEHOLDER — links mes today; replace per the WALL block above.

# --- configure loop (Model-B order) ---
for dir in intl libiberty opcodes bfd binutils gas gprof ld zlib; do
  ( cd "$dir" && \
    LD="true" AR="tcc -ar" CC="${MUSLTCC}" \
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

# --- compile: bfd headers first, then per-dir ---
make -C bfd headers
for dir in libiberty zlib bfd opcodes binutils gas gprof ld; do
  make -C "$dir" tooldir=/usr CPPFLAGS="-DPLUGIN_LITTLE_ENDIAN" MAKEINFO=true
done

# --- install + triplet symlinks ---
for dir in libiberty zlib bfd opcodes binutils gas gprof ld; do
  make -C "$dir" tooldir=/usr DESTDIR="${OUTPUT_DIR}" install MAKEINFO=true
done
cd "${OUTPUT_DIR}/usr/bin"
for f in *; do ln -s "/usr/bin/${f}" "x86_64-linux-musl-${f}"; done

###########################################################################
# BYTE-IDENTITY GATE — record-at-pin-time (no upstream amd64 binutils fixed point). Disabled for the
# capture run; pin as/ld/ar/nm/objcopy/objdump/strip + libbfd/libopcodes shas, then re-enable.
###########################################################################
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
