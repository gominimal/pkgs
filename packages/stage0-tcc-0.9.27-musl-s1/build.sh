#!/usr/bin/env bash
# R4a STAGE 1 — build the GOT-fixed tcc-0.9.27 in a CLEAN MES env (R1+R2, no R4 → no header collision).
# tcc-0.9.26 compiles tcc.c vs mes headers + links vs mes crt (mes-linked, static, self-contained). BAKED
# prefixes are MUSL (/usr/lib, /usr/include) for stage 2. Output: static mes-linked tcc-musl + libtcc1.a.
set +e
set -u
BUILDROOT="$(pwd)"
TCC26=/usr/bin/tcc-0.9.26
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s1
mkdir -p "$BINOUT" "$LIBOUT" "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

emit "S1-INFO build GOT-fixed tcc-musl (mes-linked, musl-configured) in clean MES env — $($TCC26 -version 2>&1 | head -1)"
emit "S1-INFO mes crt: $(ls -la /usr/lib/mes/crt1.o 2>/dev/null | awk '{print $5}')B  mes libc.a: $(ls -la /usr/lib/mes/libc.a 2>/dev/null | awk '{print $5}')B  mes hdr stdlib.h: $(test -f /usr/include/stdlib.h && echo yes || echo NO)"

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc.tar.gz" 2>/tmp/te; xrc=$?
[ "$xrc" = 0 ] || emit "S1-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S1-FAIL no tccsrc dir"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; cp "$TCC26" "$BINOUT/tcc-musl"; : > "$LIBOUT/libtcc1.a"; exit 0; }
: > config.h
emit "S1-INFO extracted $(ls | wc -l | tr -d ' ') files; GOT fix: $(grep -c 'R5 amd64 static-GOT fix' tccelf.c) (fill_got@$(grep -n 'fill_got(s1)' tccelf.c | head -1 | cut -d: -f1) tidy@$(grep -n 'tidy_section_headers(s1, sec_order)' tccelf.c | head -1 | cut -d: -f1))"

# libtcc1.a (x86_64) -> output (stage 2's TCC_LIBGCC=/usr/lib/tcc/libtcc1.a)
$TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/lt.o lib/libtcc1.c 2>/tmp/l1
$TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/va.o lib/va_list.c 2>/tmp/l2
$TCC26 -ar cr "$LIBOUT/libtcc1.a" /tmp/lt.o /tmp/va.o 2>/tmp/l3
emit "S1-LIBTCC1 libtcc1.a=$(ls -la $LIBOUT/libtcc1.a 2>/dev/null | awk '{print $5}')B"

# build tcc-musl: tcc-0.9.26 compiles tcc.c (MES headers, R3's -I) + links vs mes crt. BAKED = MUSL.
# tcc-0.9.26 is mes-linked -> mes-libc instability compiling the big tcc.c is a draw; retry up to 25.
TM=/build/tcc-musl
built=0
for i in $(seq 1 25); do
  rm -f "$TM"
  "$TCC26" -w -static -o "$TM" \
    -D TCC_TARGET_X86_64=1 \
    -D CONFIG_TCCDIR=\"/usr/lib/tcc\" \
    -D CONFIG_TCC_CRTPREFIX=\"/usr/lib\" \
    -D CONFIG_TCC_ELFINTERP=\"/mes/loader\" \
    -D CONFIG_TCC_LIBPATHS=\"/usr/lib:/usr/lib/tcc\" \
    -D CONFIG_TCC_SYSINCLUDEPATHS=\"/usr/include\" \
    -D TCC_LIBGCC=\"/usr/lib/tcc/libtcc1.a\" \
    -D CONFIG_TCC_STATIC=1 \
    -D CONFIG_USE_LIBGCC=1 \
    -D TCC_VERSION=\"0.9.27fixC\" \
    -D ONE_SOURCE=1 \
    -I . -I /usr/include -I /usr/include/mes \
    tcc.c 2>/tmp/be
  bc=$?
  [ -x "$TM" ] && { built=1; break; }
done
emit "S1-BUILD tcc-musl built=$built (try $i/25 last-rc=$bc be-bytes=$(wc -c </tmp/be | tr -d ' '))"
if [ "$built" = 1 ]; then
  cp "$TM" "$BINOUT/tcc-musl"
  emit "S1-OK tcc-musl: $("$TM" -version 2>&1 | head -1)"
else
  emit "S1-BUILD-ERR: $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  cp "$TCC26" "$BINOUT/tcc-musl"
fi
[ -f "$LIBOUT/libtcc1.a" ] || : > "$LIBOUT/libtcc1.a"

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s1 (GOT-fixed mes-linked tcc, clean MES env) ============"
  grep "S1-" /build/tm/rows.txt
  echo "READ: S1-OK + libtcc1.a>0 => stage-1 tcc-musl built; stage 2 (vs R4 musl) tests the GOT fix."
} | tee "$MAN"
exit 0
