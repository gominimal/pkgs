#!/usr/bin/env bash
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

# WALL RESOLVED: CC = tcc-musl2 (R4a/s3 — tcc-0.9.27 with static-link fixes A+B+C, rebuilt musl-linked so
# it is stable, not mes-libc-lottery-flaky). It links RUNNING static musl binaries (proven s2i/s3).
# A CC WRAPPER handles the abort/libtcc1<->libc cycle (fix-D can't live in tcc — it crashes tcc-0.9.26's
# compile): on LINK use the explicit `crt1 crti <args> libc.a libtcc1.a libc.a crtn` order (libc twice);
# on COMPILE (-c/-S/-E) pass through. tcc -ar is used directly for archives.
cat > "${BUILDROOT}/musl-cc" <<'WRAP'
#!/bin/sh
# ANTI-POLLUTION: compile/link against the CLEAN single-writer musl sysroot R4b publishes at
# /usr/lib/musl-bedrock, NOT the merged /usr.  The glibc-linked shell tools in this sandbox carry a
# `glibc` runtime_dep that ALSO ships usr/include/** + usr/lib/libc.a, and minimal's rootfs overlay is an
# UNORDERED hash-set with FIRST-writer-wins collisions — so /usr/{include,lib}/libc.a is a random
# musl-vs-glibc coin-flip per build.  When glibc wins, tcc chokes on glibc's stdio.h / links the wrong
# libc.  -nostdinc -I $MB/include + explicit crt/libc from $MB/lib make every binutils compile+link
# deterministic and immune.  (/usr/lib/tcc/libtcc1.a stays as-is: s3 is its sole writer — no collision.)
MB=/usr/lib/musl-bedrock
for a in "$@"; do case "$a" in -c|-S|-E) exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" "$@" ;; esac; done
exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" -nostdlib -static \
  "$MB/lib/crt1.o" "$MB/lib/crti.o" "$@" \
  "$MB/lib/libc.a" /usr/lib/tcc/libtcc1.a "$MB/lib/libc.a" "$MB/lib/crtn.o"
WRAP
chmod +x "${BUILDROOT}/musl-cc"
MUSLTCC="${BUILDROOT}/musl-cc"

# --- configure loop (Model-B order) ---
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
