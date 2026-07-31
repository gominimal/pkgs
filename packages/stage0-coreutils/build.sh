#!/bin/sh
# stage0-coreutils — build the bedrock's own coreutils with tcc-musl, never with gcc.
#
# See build.ncl for why this rung exists and how each flag below was arrived at. In short: 23
# bedrock rungs depend on `coreutils`, which imports gcc/glibc/binutils directly, and that single
# edge is what keeps the 7 toolchain anchors operator-pinned.
#
# Every setting here corresponds to a MEASURED failure from the 2026-07-31 experiment, not to
# guesswork. Where a value answers an autoconf probe rather than patching source, that is
# deliberate: this rung must not modify shipped coreutils sources.
set -eu

MB=/usr/lib/musl-bedrock            # the cc2 sysroot: headers + crt1/crti/crtn + libc.a
TCC=/usr/bin/tcc-musl2
LIBTCC1=/usr/lib/tcc/libtcc1.a      # the "alloca provider" (same role R12 gives it)
OUT="${OUTPUT_DIR:?OUTPUT_DIR required}"

# ---- infra guards: name the missing artifact rather than failing 2000 lines into a build ----
[ -x "$TCC" ]            || { echo "stage0-coreutils: no tcc at $TCC" >&2; exit 1; }
[ -d "$MB/include" ]     || { echo "stage0-coreutils: no musl headers at $MB/include" >&2; exit 1; }
[ -f "$MB/lib/crt1.o" ]  || { echo "stage0-coreutils: no crt1.o at $MB/lib" >&2; exit 1; }
[ -f "$LIBTCC1" ]        || { echo "stage0-coreutils: no libtcc1.a at $LIBTCC1" >&2; exit 1; }
command -v ld >/dev/null || { echo "stage0-coreutils: no ld on PATH (need stage0-binutils)" >&2; exit 1; }

# ASSERT WE HAVE THE TCC-COMPATIBLE MUSL, not the gcc-built stock one. Getting this wrong is what
# produced "bits/alltypes.h: ';' expected (got \"va_list\")" for an entire debugging session:
# stage0-musl-1.2.5 carries none of the tcc workarounds; the cc2 variant defines __builtin_va_list
# via tcc's SysV __va_list_struct. Checking the marker is cheap; discovering it via a compile
# failure is not.
grep -q '__TINYC_va_list_defined' "$MB/include/bits/alltypes.h" || {
  echo "stage0-coreutils: $MB is NOT the tcc-patched musl (no __TINYC_va_list_defined)" >&2
  echo "  this rung requires stage0-musl-1.1.24-cc2, not stage0-musl-1.2.5" >&2
  exit 1
}

# ---- the compiler wrapper, mirroring stage0-gcc-4.0.4's musl-cc ----
# -nostdinc + explicit -I: the coin-flip /usr/include carries glibc headers that collide with musl
# under minimal's first-writer-wins rootfs (the anti-pollution rationale stage0-gcc-4.0.4 documents).
# $LIBTCC1 on the LINK line only: with musl's alloca.h suppressed, tcc emits a call to alloca.
CC_WRAP="$(pwd)/musl-cc"
cat > "$CC_WRAP" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $TCC -nostdinc -I "$MB/include" "\$@" ;; esac; done
exec $TCC -nostdinc -I "$MB/include" -B "$MB/lib" -L "$MB/lib" "\$@" $LIBTCC1
WRAP
chmod 0755 "$CC_WRAP"

# ---- gate BEFORE the build: a compiler that cannot produce a running binary fails now, not in
# ---- the middle of a 300-file make.
cat > /tmp/cc-probe.c <<'EOF'
#include <stdio.h>
int main(void) { puts("cc-ok"); return 0; }
EOF
"$CC_WRAP" -static -o /tmp/cc-probe /tmp/cc-probe.c
[ "$(/tmp/cc-probe)" = "cc-ok" ] || { echo "stage0-coreutils: tcc cannot build a running binary" >&2; exit 1; }
echo "stage0-coreutils: compiler gate PASS (tcc-musl2 + $MB)" >&2

cd coreutils-5.0

export CC="$CC_WRAP"
# -D_ALLOCA_H: musl's alloca.h declares `void *alloca(size_t)` while tcc has a builtin of a
# different type => "incompatible types for redefinition of 'alloca'". Pre-defining the guard skips
# the header; the file on disk is untouched.
export CFLAGS="-static -D_GNU_SOURCE -D_ALLOCA_H"

# Autoconf answers, all responses to measured probe failures under tcc:
export ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
# COHERENT alloca answer: header absent AND works=no, so configure builds coreutils' own
# lib/alloca.c. Saying works=yes here leaves alloca undefined at link for every tool that uses one
# (du/ls/dir/vdir/ginstall fail; chmod/rm, which use none, link fine) — that asymmetry is how the
# inconsistency was found.
export ac_cv_header_alloca_h=no ac_cv_func_alloca_works=no
# coreutils 5.0 predates functions musl 1.1.24 provides and ships colliding declarations
# (e.g. ../lib/getline.h:32 "incompatible types for redefinition of 'getline'").
export ac_cv_func_getline=yes ac_cv_func_getdelim=yes
export ac_cv_func_strndup=yes ac_cv_func_strnlen=yes
export ac_cv_func_mkstemp=yes ac_cv_func_memrchr=yes

./configure --disable-nls --prefix=/usr
make -j"${MAKE_JOBS:-4}"
make DESTDIR="$OUT" install

# ============================== FUNCTIONAL GATE ==============================
# "It built" is NOT accepted as proof. sha256sum must reproduce a known digest — a hash tool that
# runs and computes garbage is worse than one that fails, because everything above this rung uses
# it as a byte-identity gate.
SHA="$OUT/usr/bin/sha256sum"
[ -x "$SHA" ] || { echo "CU-GATE: FAIL (no sha256sum installed)" >&2; exit 1; }
printf 'abc' > /tmp/cu-gate.txt
GOT="$("$SHA" /tmp/cu-gate.txt | cut -d' ' -f1)"
WANT=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
echo "CU-GATE diag: sha256sum('abc') = $GOT" >&2
[ "$GOT" = "$WANT" ] || { echo "CU-GATE: FAIL (expected $WANT)" >&2; exit 1; }

for t in chmod cp mkdir rm; do
  [ -x "$OUT/usr/bin/$t" ] || { echo "CU-GATE: FAIL ($t missing)" >&2; exit 1; }
  "$OUT/usr/bin/$t" --version >/dev/null 2>&1 || { echo "CU-GATE: FAIL ($t does not run)" >&2; exit 1; }
done
echo "CU-GATE: PASS (5 tools built by tcc-musl; sha256sum digest verified; no gcc in this rung)" >&2
