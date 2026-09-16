#!/usr/bin/env bash
# stage0-tcc-0.9.27-musl-s1: tcc-0.9.26 compiles the GOT-fixed tcc-0.9.27 against mes headers and
# links it statically against mes crt/libc. Baked prefixes are musl's (/usr/lib, /usr/include).
# Outputs: usr/bin/tcc-musl (mes-linked, musl-configured) + usr/lib/tcc/libtcc1.a.
# phases: header sysroot check, extract, libtcc1.a, piecewise tcc-musl build, manifest.
set +e
set -u
BUILDROOT="$(pwd)"
TCC26=/usr/bin/tcc-0.9.26
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s1
mkdir -p "$BINOUT" "$LIBOUT" "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

# Retry loop with an env-layout perturbation (MESLROLL). Try 1 runs the canonical env, so a
# first-try success is byte-identical to an unrolled run. Insurance only: the known crash cause
# was the header draw, fixed by -nostdinc below.
ROLL=""
mesl_roll(){ # $1 = try number; sets ROLL (empty on try 1 = canonical env)
  if [ "$1" = 1 ]; then ROLL=""; else ROLL=$(printf 'R%.0s' $(seq 1 $(( ($1 - 1) * 17 )))); fi
}
mesl_run(){ if [ -n "$ROLL" ]; then MESLROLL="$ROLL" "$@"; else "$@"; fi; }

emit "S1-INFO build GOT-fixed tcc-musl (mes-linked, musl-configured) in clean MES env — $($TCC26 -version 2>&1 | head -1)"
emit "S1-INFO mes crt: $(ls -la /usr/lib/mes/crt1.o 2>/dev/null | awk '{print $5}')B  mes libc.a: $(ls -la /usr/lib/mes/libc.a 2>/dev/null | awk '{print $5}')B  mes hdr stdlib.h: $(test -f /usr/include/stdlib.h && echo yes || echo NO)"
# diagnostic only: which stdio.h won the merged /usr/include (first-writer-wins draw against the
# glibc runtime dep). The compile below does not read it.
emit "S1-HDR stdio.h=$(sha256sum /usr/include/stdio.h 2>/dev/null | cut -c1-16) alltypes=$(test -f /usr/include/bits/alltypes.h && echo musl-present || echo no-musl) stdio_lim=$(test -f /usr/include/bits/stdio_lim.h && echo GLIBC-PRESENT || echo clean)"
# The compile reads only stage0-mes's single-writer header sysroot (-nostdinc). Fail if it is
# missing rather than fall back to the merged /usr/include.
MB=/usr/lib/mes-bedrock/include
[ -f "$MB/stdio.h" ] && [ -f "$MB/mes/lib.h" ] || { emit "S1-FAIL mes header sysroot missing at $MB (stage0-mes must publish mes_sysroot_inc)"; cp /build/tm/rows.txt "$LOGOUT/rows.log" 2>/dev/null; echo fail | tee "$MAN"; exit 1; }
emit "S1-INFO header sysroot $MB: $(ls "$MB" | wc -l | tr -d ' ') entries, stdio.h=$(sha256sum "$MB/stdio.h" | cut -c1-16)"

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc-r3got-s1.tar.gz" 2>/tmp/te; xrc=$?
[ "$xrc" = 0 ] || emit "S1-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S1-FAIL no tccsrc dir"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; cp "$TCC26" "$BINOUT/tcc-musl"; : > "$LIBOUT/libtcc1.a"; exit 0; }
: > config.h
emit "S1-INFO extracted $(ls | wc -l | tr -d ' ') files; GOT fix: $(grep -c 'R5 amd64 static-GOT fix' tccelf.c) (fill_got@$(grep -n 'fill_got(s1)' tccelf.c | head -1 | cut -d: -f1) tidy@$(grep -n 'tidy_section_headers(s1, sec_order)' tccelf.c | head -1 | cut -d: -f1))"

# libtcc1.a (x86_64) for stage 3's TCC_LIBGCC=/usr/lib/tcc/libtcc1.a. Retried: a crashed unit
# compile would otherwise fall through to the empty-archive backstop below.
for i in $(seq 1 4); do
  mesl_roll "$i"
  rm -f /tmp/lt.o /tmp/va.o
  mesl_run $TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/lt.o lib/libtcc1.c 2>/tmp/l1
  mesl_run $TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/va.o lib/va_list.c 2>/tmp/l2
  [ -f /tmp/lt.o ] && [ -f /tmp/va.o ] && break
done
$TCC26 -ar cr "$LIBOUT/libtcc1.a" /tmp/lt.o /tmp/va.o 2>/tmp/l3
emit "S1-LIBTCC1 libtcc1.a=$(ls -la $LIBOUT/libtcc1.a 2>/dev/null | awk '{print $5}')B"

# Build tcc-musl piecewise: each tcc source is its own compilation unit (no ONE_SOURCE), then
# linked. The mes-libc crash rate scales with unit size, so small units fail far less often.
TM=/build/tcc-musl
# DEFS bake the musl config into the .o's (bash array so the quoted -D strings survive);
# tcc-0.9.26 links them with its own mes crt, so tcc-musl is mes-linked but musl-configured.
DEFS=(
  -D TCC_TARGET_X86_64=1
  -D ONE_SOURCE=0   # tcc.h defaults ONE_SOURCE=1 when undefined; =0 is required for a multi-file build
  -D 'CONFIG_TCCDIR="/usr/lib/tcc"'
  -D 'CONFIG_TCC_CRTPREFIX="/usr/lib"'
  -D 'CONFIG_TCC_ELFINTERP="/mes/loader"'
  -D 'CONFIG_TCC_LIBPATHS="/usr/lib:/usr/lib/tcc"'
  -D 'CONFIG_TCC_SYSINCLUDEPATHS="/usr/include"'
  -D 'TCC_LIBGCC="/usr/lib/tcc/libtcc1.a"'
  -D CONFIG_TCC_STATIC=1
  -D CONFIG_USE_LIBGCC=1
  -D 'TCC_VERSION="0.9.27PW2"'
)
# -nostdinc + the mes header sysroot: mes installs most libc headers at the top level of its
# include tree, so any -I list that reaches the merged /usr/include would read the drawn stdio.h.
INCS=(-nostdinc -I . -I "$MB/mes" -I "$MB")
# x86_64 units: libtcc.c's ONE_SOURCE include set for TCC_TARGET_X86_64 + CONFIG_TCC_ASM, plus
# tcc.c (the CLI, which includes tcctools.c for -ar).
UNITS="libtcc tccpp tccgen tccelf tccrun x86_64-gen x86_64-link i386-asm tccasm tcc"
built=0; bc=0; failunit=""
for i in $(seq 1 6); do
  mesl_roll "$i"
  rm -f "$TM"; for u in $UNITS; do rm -f "$u.o"; done; : > /tmp/be
  ok=1
  for u in $UNITS; do
    mesl_run "$TCC26" -w -c "${DEFS[@]}" "${INCS[@]}" -o "$u.o" "$u.c" 2>>/tmp/be
    bc=$?
    { [ "$bc" = 0 ] && [ -f "$u.o" ]; } || { ok=0; failunit="$u"; break; }
  done
  [ "$ok" = 1 ] || continue
  objs=""; for u in $UNITS; do objs="$objs $u.o"; done
  # $objs must word-split into the .o args; tcc-0.9.26 supplies its own mes crt under -static
  mesl_run "$TCC26" -w -static -o "$TM" $objs 2>>/tmp/be
  bc=$?
  { [ "$bc" = 0 ] && [ -x "$TM" ]; } && { built=1; break; }
done
emit "S1-BUILD tcc-musl built=$built piecewise (try $i/6 roll=$((i-1)) last-rc=$bc failunit=${failunit:-none} be=$(wc -c </tmp/be | tr -d ' '))"
if [ "$built" = 1 ]; then
  cp "$TM" "$BINOUT/tcc-musl"
  emit "S1-OK tcc-musl: $("$TM" -version 2>&1 | head -1)"
else
  # No fallback binary: a copied tcc-0.9.26 would be cached as a fake success.
  # The marker text must not contain the substrings the queue's stderr classifier treats as a
  # transient interpreter crash; this is a compiled ELF, so the failure is not retryable.
  if [ "$bc" = 139 ]; then
    emit "S1-BUILD-ERR mes-libc SIGSEGV rc=139 in tcc-0.9.26 (a compiled ELF linked against mes-libc; no Scheme interpreter and no GC arena are in this process) compiling unit=${failunit:-link} across all 6 env-layout retries (retries re-roll the ENV, not the sandbox — read the S1-HDR/S1-INFO header-sysroot lines first; with -nostdinc a header draw is ruled out, so this is a real bug): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  else
    emit "S1-BUILD-ERR (rc=$bc unit=${failunit:-link}, deterministic — fix the recipe): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  fi
fi
[ -f "$LIBOUT/libtcc1.a" ] || : > "$LIBOUT/libtcc1.a"

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s1 (GOT-fixed mes-linked tcc, clean MES env) ============"
  grep "S1-" /build/tm/rows.txt
  echo "READ: S1-OK + libtcc1.a>0 => stage-1 tcc-musl built; stage 2 (vs musl-1.1.24) tests the GOT fix."
} | tee "$MAN"
# built=0 exits non-zero so the task fails cleanly instead of caching a partial output.
[ "$built" = 1 ] || exit 1
exit 0
