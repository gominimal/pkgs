#!/usr/bin/env bash
# tcc-boot0-diag — ONE-build diagnostic: WHERE does tcc-boot0 crash? (see build.ncl for full rationale)
# Builds the PATCHED tcc-mes (field-by-field swap), rebuilds mes-libc with it, builds tcc-boot0 (with
# the -I ${PREFIX}/include fix), then runs a battery that isolates tcc-mes-codegen vs libc.a vs the
# inline-assembler subsystem vs the >=4-arg/c-union swap. Probe, not a trust rung: set +e, never abort.
#
# Greppable markers (stdout AND MANIFEST):
#   DIAG-INFO    ...                                   progress
#   DIAG-RESULT  <label> <OUTCOME> rc=<rc> ...         one per battery test
#   DIAG-TABLE   ...                                   final matrix
#   FATAL        ...                                   a build phase failed (STILL exits 0)
set +e
set -u

# ── env: MUST match production R2 tcc.kaem so the diagnosis is faithful ──
export MES_PREFIX=/usr
export GUILE_LOAD_PATH=/usr/share/mes/mes/module:/usr/share/mes/module:/usr/share/nyacc/module
export MES_STACK=15000000
export MES_ARENA=50000000          # no-growth (MES_ARENA==MES_MAX_ARENA), the reliable R2 path
export MES_MAX_ARENA=50000000

MES=/usr/bin/mes-m2
MESCC=/usr/bin/mescc.scm
INCDIR=/usr/include/mes
MES_ARCH=x86_64
PREFIX=/usr
TCC_PKG=tcc-0.9.26-1147-gee75a10c
MES_PKG=mes-0.27.1
BINDIR=/build/output/usr/bin
LIBDIR=/build/output/usr/lib/mes
TCCMES=$BINDIR/tcc-mes
TCCBOOT0=$BINDIR/tcc-boot0

STAGE_TIMEOUT=600
LINK_TIMEOUT=300
UNIT_TIMEOUT=120
RUN_TIMEOUT=30

OUTROOT=/build/output/usr/share/tcc-boot0-diag
WORK=/build/diag-logs
mkdir -p "$OUTROOT" "$WORK" "$BINDIR" "$LIBDIR"
MANIFEST="$OUTROOT/MANIFEST.txt"
XGEN=/build/$TCC_PKG/x86_64-gen.c

# results accumulated for the final table
declare -A R

emit() { echo "$1"; echo "$1" >> "$WORK/rows.txt"; }

# ── the catm list for unified-libc.c (verbatim from R2 tcc.kaem:194, MES_ARCH=x86_64) ──
LIBC_FILES="ctype/isalnum.c ctype/isalpha.c ctype/isascii.c ctype/iscntrl.c ctype/isdigit.c ctype/isgraph.c ctype/islower.c ctype/isnumber.c ctype/isprint.c ctype/ispunct.c ctype/isspace.c ctype/isupper.c ctype/isxdigit.c ctype/tolower.c ctype/toupper.c dirent/closedir.c dirent/__getdirentries.c dirent/opendir.c linux/readdir.c linux/access.c linux/brk.c linux/chdir.c linux/chmod.c linux/clock_gettime.c linux/close.c linux/dup2.c linux/dup.c linux/execve.c linux/fcntl.c linux/fork.c linux/fsync.c linux/fstat.c linux/_getcwd.c linux/getdents.c linux/getegid.c linux/geteuid.c linux/getgid.c linux/getpid.c linux/getppid.c linux/getrusage.c linux/gettimeofday.c linux/getuid.c linux/ioctl.c linux/ioctl3.c linux/kill.c linux/link.c linux/lseek.c linux/lstat.c linux/malloc.c linux/mkdir.c linux/mknod.c linux/nanosleep.c linux/_open3.c linux/pipe.c linux/_read.c linux/readlink.c linux/rename.c linux/rmdir.c linux/setgid.c linux/settimer.c linux/setuid.c linux/signal.c linux/sigprogmask.c linux/symlink.c linux/stat.c linux/time.c linux/unlink.c linux/waitpid.c linux/wait4.c linux/${MES_ARCH}-mes-gcc/_exit.c linux/${MES_ARCH}-mes-gcc/syscall.c linux/${MES_ARCH}-mes-gcc/_write.c math/ceil.c math/fabs.c math/floor.c mes/abtod.c mes/abtol.c mes/__assert_fail.c mes/assert_msg.c mes/__buffered_read.c mes/__init_io.c mes/cast.c mes/dtoab.c mes/eputc.c mes/eputs.c mes/fdgetc.c mes/fdgets.c mes/fdputc.c mes/fdputs.c mes/fdungetc.c mes/globals.c mes/itoa.c mes/ltoab.c mes/ltoa.c mes/__mes_debug.c mes/mes_open.c mes/ntoab.c mes/oputc.c mes/oputs.c mes/search-path.c mes/ultoa.c mes/utoa.c posix/alarm.c posix/buffered-read.c posix/execl.c posix/execlp.c posix/execv.c posix/execvp.c posix/getcwd.c posix/getenv.c posix/isatty.c posix/mktemp.c posix/open.c posix/pathconf.c posix/raise.c posix/sbrk.c posix/setenv.c posix/sleep.c posix/unsetenv.c posix/wait.c posix/write.c stdio/clearerr.c stdio/fclose.c stdio/fdopen.c stdio/feof.c stdio/ferror.c stdio/fflush.c stdio/fgetc.c stdio/fgets.c stdio/fileno.c stdio/fopen.c stdio/fprintf.c stdio/fputc.c stdio/fputs.c stdio/fread.c stdio/freopen.c stdio/fscanf.c stdio/fseek.c stdio/ftell.c stdio/fwrite.c stdio/getc.c stdio/getchar.c stdio/perror.c stdio/printf.c stdio/putc.c stdio/putchar.c stdio/remove.c stdio/snprintf.c stdio/sprintf.c stdio/sscanf.c stdio/ungetc.c stdio/vfprintf.c stdio/vfscanf.c stdio/vprintf.c stdio/vsnprintf.c stdio/vsprintf.c stdio/vsscanf.c stdlib/abort.c stdlib/abs.c stdlib/alloca.c stdlib/atexit.c stdlib/atof.c stdlib/atoi.c stdlib/atol.c stdlib/calloc.c stdlib/__exit.c stdlib/exit.c stdlib/free.c stdlib/mbstowcs.c stdlib/puts.c stdlib/qsort.c stdlib/realloc.c stdlib/strtod.c stdlib/strtof.c stdlib/strtol.c stdlib/strtold.c stdlib/strtoll.c stdlib/strtoul.c stdlib/strtoull.c string/bcmp.c string/bcopy.c string/bzero.c string/index.c string/memchr.c string/memcmp.c string/memcpy.c string/memmem.c string/memmove.c string/memset.c string/rindex.c string/strcat.c string/strchr.c string/strcmp.c string/strcpy.c string/strcspn.c string/strdup.c string/strerror.c string/strlen.c string/strlwr.c string/strncat.c string/strncmp.c string/strncpy.c string/strpbrk.c string/strrchr.c string/strspn.c string/strstr.c string/strupr.c stub/atan2.c stub/bsearch.c stub/chown.c stub/__cleanup.c stub/cos.c stub/ctime.c stub/exp.c stub/fpurge.c stub/freadahead.c stub/frexp.c stub/getgrgid.c stub/getgrnam.c stub/getlogin.c stub/getpgid.c stub/getpgrp.c stub/getpwnam.c stub/getpwuid.c stub/gmtime.c stub/ldexp.c stub/localtime.c stub/log.c stub/mktime.c stub/modf.c stub/mprotect.c stub/pclose.c stub/popen.c stub/pow.c stub/putenv.c stub/rand.c stub/realpath.c stub/rewind.c stub/setbuf.c stub/setgrent.c stub/setlocale.c stub/setvbuf.c stub/sigaction.c stub/sigaddset.c stub/sigblock.c stub/sigdelset.c stub/sigemptyset.c stub/sigsetmask.c stub/sin.c stub/sys_siglist.c stub/system.c stub/sqrt.c stub/strftime.c stub/times.c stub/ttyname.c stub/umask.c stub/utime.c ${MES_ARCH}-mes-gcc/setjmp.c"

# ── write the three battery test programs (no headers needed) ─────────────────────────────────
write_test_programs() {
  cat > "$WORK/hello.c" <<'EOF'
int main (int argc, char *argv[], char *envp[]) { return 42; }
EOF
  # f() has 5 int args: the 4th(d)+5th(e) are the >=4-arg path; constants 4,5 live in CValue.c.
  # 1 + 2*2 + 3*3 + 4*4 + 5*5 = 1+4+9+16+25 = 55. Wrong => the c-union swap corrupts constant args.
  cat > "$WORK/const4arg.c" <<'EOF'
int f (int a, int b, int c, int d, int e) { return a + b*2 + c*3 + d*4 + e*5; }
int main (int argc, char *argv[], char *envp[]) { return f (1, 2, 3, 4, 5); }
EOF
  # basic inline asm in crt1.c's idiom (mov-imm, add-imm, shl-imm, mov reg-reg, syscall exit). rc=7.
  cat > "$WORK/asmtest.c" <<'EOF'
int main (int argc, char *argv[], char *envp[])
{
  asm ("mov $1,%rax\n\t"
       "add $2,%rax\n\t"
       "shl $1,%rax\n\t"
       "add $1,%rax\n\t"
       "mov %rax,%rdi\n\t"
       "mov $0x3c,%rax\n\t"
       "syscall\n\t");
  return 0;
}
EOF
}

# ── compile+link+RUN a test program with $1 compiler; expect rc==$3. Sets R[$4]. ──────────────
build_and_run() {
  local cc="$1" src="$2" exp="$3" label="$4"
  local bin="$WORK/$label.bin"
  rm -f "$bin"
  timeout "$UNIT_TIMEOUT" "$cc" -static -o "$bin" -L . -L "$LIBDIR" "$src" \
    >"$WORK/$label.cc.out" 2>"$WORK/$label.cc.err"
  local crc=$?
  if [ "$crc" != "0" ] || [ ! -s "$bin" ]; then
    R[$label]="COMPILE/LINK-FAIL(rc=$crc)"
    emit "DIAG-RESULT $label COMPILE/LINK-FAIL rc=$crc >>> $(tail -2 "$WORK/$label.cc.err" 2>/dev/null | tr '\n' '|')"
    return
  fi
  /usr/bin/chmod 755 "$bin"
  timeout "$RUN_TIMEOUT" "$bin" >"$WORK/$label.run.out" 2>"$WORK/$label.run.err"
  local rrc=$?
  if [ "$rrc" = "$exp" ]; then
    R[$label]="RUN-OK(rc=$rrc)"
    emit "DIAG-RESULT $label RUN-OK rc=$rrc (expected $exp)"
  else
    R[$label]="RUN-WRONG(rc=$rrc want $exp)"
    emit "DIAG-RESULT $label RUN-WRONG rc=$rrc (expected $exp) — wrong codegen or crash >>> $(tail -2 "$WORK/$label.run.err" 2>/dev/null | tr '\n' '|')"
  fi
}

# ════════════════════════════════════════════════════════════════════════════════════════════
emit "DIAG-INFO begin: tcc-boot0-diag (mes-m2: $($MES --version 2>&1 | head -1 || true))"
# DIAG: is the sandbox's ADDR_NO_RANDOMIZE (MINIMAL_SANDBOX_NO_ASLR) actually reaching this process?
# /proc/self/personality with the 0x0040000 bit set == ADDR_NO_RANDOMIZE active (inherited by mes child).
# If '?', /proc isn't mounted in the sandbox (then the personality lever is unobservable here).
emit "DIAG-ASLR personality=$(/usr/bin/cat /proc/self/personality 2>/dev/null || echo '?') randomize_va_space=$(/usr/bin/cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo '?') (0x40000 personality bit => NO_RANDOMIZE active)"
[ -f "$XGEN" ] || { echo "FATAL: $XGEN missing"; echo "FATAL: $XGEN missing" > "$MANIFEST"; exit 0; }
command -v simple-patch >/dev/null 2>&1 || { echo "FATAL: simple-patch missing" | tee "$MANIFEST"; exit 0; }
write_test_programs

# ── PHASE 1: patches (tcctools fopen + field-by-field swap), all in the tcc tree ──────────────
simple-patch "/build/$TCC_PKG/tcctools.c" /build/remove-fileopen.before /build/remove-fileopen.after \
  && simple-patch "/build/$TCC_PKG/tcctools.c" /build/addback-fileopen.before /build/addback-fileopen.after \
  && emit "DIAG-INFO tcctools.c fopen patches applied" || emit "FATAL tcctools.c patch failed"
SWAP_OK=1
for p in fix-swapf fix-swapb; do
  simple-patch "$XGEN" "/build/$p.before" "/build/$p.after" \
    && emit "DIAG-INFO applied $p (field-by-field swap)" \
    || { emit "FATAL swap patch $p FAILED (before-pattern not found)"; SWAP_OK=0; }
done
# BUG1 (static-PLT crash, genuine tcc -static defect): build_got_entries -> convert PLT32/PC32 to
# direct PC32 for defined syms in static link (no PLT). BUG2 (mescc miscompiles the log2 loop):
# rewrite the strength-reduction shift-count loop mescc-safe. (workflow wf_9d59a528, gcc-verified BUG1.)
simple-patch "/build/$TCC_PKG/tccelf.c" /build/fix-plt.before /build/fix-plt.after \
  && emit "DIAG-INFO applied fix-plt (static-PLT->PC32, tccelf.c)" \
  || { emit "FATAL fix-plt patch FAILED (before-pattern not found)"; SWAP_OK=0; }
simple-patch "/build/$TCC_PKG/tccgen.c" /build/fix-mul.before /build/fix-mul.after \
  && emit "DIAG-INFO applied fix-mul (strength-reduction log2, tccgen.c)" \
  || { emit "FATAL fix-mul patch FAILED (before-pattern not found)"; SWAP_OK=0; }
simple-patch "$XGEN" /build/fix-vararg.before /build/fix-vararg.after \
  && emit "DIAG-INFO applied fix-vararg (variadic %al setup, x86_64-gen.c)" \
  || { emit "FATAL fix-vararg patch FAILED (before-pattern not found)"; SWAP_OK=0; }
[ "$SWAP_OK" = "1" ] || { echo "FATAL: a patch did not apply — aborting (see rows)"; cp "$WORK/rows.txt" "$MANIFEST" 2>/dev/null; exit 0; }

# ── PHASE 2: build tcc-mes (mescc compiles tcc.c -> tcc.s -> link). The arena-lottery long pole. ──
cd "/build/$TCC_PKG" || { echo "FATAL cd tcc"; exit 0; }
: > config.h
MESCC_ARGS=(
  -S -o tcc.s -I "$INCDIR" -D BOOTSTRAP=1 -D HAVE_LONG_LONG=1 -I . -D TCC_TARGET_X86_64=1 -D inline=
  -D "CONFIG_TCCDIR=\"$LIBDIR/tcc\"" -D "CONFIG_SYSROOT=\"/\"" -D "CONFIG_TCC_CRTPREFIX=\"$LIBDIR\""
  -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\"" -D "CONFIG_TCC_SYSINCLUDEPATHS=\"$PREFIX/include/mes\""
  -D "TCC_LIBGCC=\"$LIBDIR/libc.a\"" -D CONFIG_TCC_LIBTCC1_MES=0 -D CONFIG_TCCBOOT=1
  -D CONFIG_TCC_STATIC=1 -D CONFIG_USE_LIBGCC=1 -D "TCC_VERSION=\"0.9.26\"" -D ONE_SOURCE=1 tcc.c
)
emit "DIAG-INFO mescc tcc.c -> tcc.s (no-growth arena, ~250s; ARENA-LOTTERY draw) ..."
t0=$SECONDS
timeout "$STAGE_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- "${MESCC_ARGS[@]}" \
  >"$WORK/mescc.out" 2>"$WORK/mescc.err"
mrc=$?
emit "DIAG-INFO mescc rc=$mrc $((SECONDS-t0))s ($(/usr/bin/wc -l < tcc.s 2>/dev/null || echo 0) lines tcc.s)"
if [ "$mrc" != "0" ] || [ ! -s tcc.s ]; then
  emit "FATAL mescc tcc.c->tcc.s FAILED (rc=$mrc — likely the arena lottery; RE-ENQUEUE) >>> $(tail -4 "$WORK/mescc.err" 2>/dev/null | tr '\n' '|')"
  cp "$WORK/rows.txt" "$MANIFEST" 2>/dev/null; exit 0
fi
timeout "$LINK_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- \
  --base-address 0x08048000 -o tcc-mes -L "$LIBDIR" tcc.s -l c+tcc \
  >"$WORK/link.out" 2>"$WORK/link.err"
lrc=$?
if [ "$lrc" != "0" ] || [ ! -s tcc-mes ]; then
  emit "FATAL tcc-mes link FAILED (rc=$lrc) >>> $(tail -4 "$WORK/link.err" 2>/dev/null | tr '\n' '|')"
  cp "$WORK/rows.txt" "$MANIFEST" 2>/dev/null; exit 0
fi
/usr/bin/cp tcc-mes "$TCCMES" && /usr/bin/chmod 755 "$TCCMES"
/usr/bin/cp tcc-mes "$OUTROOT/tcc-mes.patched"
"$TCCMES" -version >"$WORK/tccmes-version.out" 2>&1
emit "DIAG-INFO tcc-mes built; -version rc=$? : $(head -1 "$WORK/tccmes-version.out")"

# ── PHASE 3: rebuild mes-libc WITH tcc-mes (crt1.o + unified-libc.a + libtcc1.a + libgetopt.a) ──
cd "/build/$MES_PKG" || { echo "FATAL cd mes"; exit 0; }
: > include/mes/config.h
mkdir -p include/arch
/usr/bin/cp "include/linux/$MES_ARCH/kernel-stat.h" include/arch/kernel-stat.h
/usr/bin/cp "include/linux/$MES_ARCH/signal.h"      include/arch/signal.h
/usr/bin/cp "include/linux/$MES_ARCH/syscall.h"     include/arch/syscall.h
# BUG (5th): mes-libc setjmp uses EXTENDED-asm output operand which tcc-mes miscompiles -> tcc-boot0
# crashes at libtcc.c:638 setjmp on every compile. Rewrite setjmp.c to pure BASIC asm before catm.
simple-patch "lib/$MES_ARCH-mes-gcc/setjmp.c" /build/fix-setjmp.before /build/fix-setjmp.after \
  && emit "DIAG-INFO applied fix-setjmp (basic-asm setjmp, mes-libc)" \
  || emit "FATAL fix-setjmp patch FAILED (before-pattern not found)"
# THE varargs ROOT CAUSE: mes amd64 stdarg.h uses a STACK-based va_list incompatible with tcc-mes's
# SysV register-passing -> use tcc's __builtin_va_* under __TINYC__ (mescc keeps the stack version).
simple-patch "include/stdarg.h" /build/fix-stdarg.before /build/fix-stdarg.after \
  && emit "DIAG-INFO applied fix-stdarg (SysV __builtin_va_* for tcc-mes)" \
  || emit "FATAL fix-stdarg patch FAILED (before-pattern not found)"
( cd lib && /usr/bin/cat $LIBC_FILES > ../unified-libc.c ) \
  && emit "DIAG-INFO unified-libc.c assembled ($(/usr/bin/wc -l < unified-libc.c) lines)" \
  || emit "FATAL could not assemble unified-libc.c"
LC="-c -D HAVE_CONFIG_H=1 -I include -I include/linux/$MES_ARCH"
timeout "$UNIT_TIMEOUT" "$TCCMES" $LC -o "$LIBDIR/crt1.o" "lib/linux/$MES_ARCH-mes-gcc/crt1.c" >"$WORK/crt1.out" 2>&1
emit "DIAG-INFO tcc-mes -c crt1.c rc=$? ($([ -s "$LIBDIR/crt1.o" ] && echo OBJ-OK || echo NO-OBJ))"
# amd64: crti.o/crtn.o are EMPTY placeholders (R2 kaem `catm ${LIBDIR}/crt{i,n}.o`); tcc auto-adds
# crt1.o+crti.o+crtn.o from CRTPREFIX at every link, so the FILES must exist (x86 compiles real ones).
: > "$LIBDIR/crti.o"
: > "$LIBDIR/crtn.o"
emit "DIAG-INFO created empty crti.o/crtn.o placeholders (amd64; needed by every tcc link)"
timeout "$UNIT_TIMEOUT" "$TCCMES" $LC -o unified-libc.o unified-libc.c >"$WORK/ulibc.out" 2>&1
emit "DIAG-INFO tcc-mes -c unified-libc.c rc=$? ($([ -s unified-libc.o ] && echo OBJ-OK || echo NO-OBJ))"
# THE missing object: tcc-0.9.26's amd64 SysV varargs runtime (__va_start/__va_arg) lives in
# lib/va_list.c. The real tcc Makefile builds it into libtcc1.a (OBJ-x86_64 = ... va_list.o ...);
# lib/libtcc1.c does NOT contain it. Without va_list.o, EVERY link of unified-libc.o (vfprintf et al,
# now compiled with the SysV struct stdarg.h) fails: undefined symbol '__va_start'/'__va_arg'.
# __SIZE_TYPE__ is predefined by tcc (libtcc.c) so va_list.c compiles standalone; guard is TCC_TARGET_X86_64.
timeout "$UNIT_TIMEOUT" "$TCCMES" -c -D TCC_TARGET_X86_64=1 -o va_list.o "/build/$TCC_PKG/lib/va_list.c" >"$WORK/valist.out" 2>&1
emit "DIAG-INFO tcc-mes -c va_list.c rc=$? ($([ -s va_list.o ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -2 "$WORK/valist.out" 2>/dev/null | tr '\n' '|')"
"$TCCMES" -ar cr "$LIBDIR/libc.a" unified-libc.o va_list.o >>"$WORK/ulibc.out" 2>&1
mkdir -p "$LIBDIR/tcc"
timeout "$UNIT_TIMEOUT" "$TCCMES" -c -D HAVE_CONFIG_H=1 -D HAVE_LONG_LONG=1 -D HAVE_FLOAT=1 -I include -I "include/linux/$MES_ARCH" -o libtcc1.o lib/libtcc1.c >"$WORK/libtcc1.out" 2>&1
"$TCCMES" -ar cr "$LIBDIR/tcc/libtcc1.a" libtcc1.o va_list.o >>"$WORK/libtcc1.out" 2>&1
timeout "$UNIT_TIMEOUT" "$TCCMES" $LC lib/posix/getopt.c >"$WORK/getopt.out" 2>&1
"$TCCMES" -ar cr "$LIBDIR/libgetopt.a" getopt.o >>"$WORK/getopt.out" 2>&1
emit "DIAG-INFO libc.a=$([ -s "$LIBDIR/libc.a" ] && echo ok || echo MISSING) libtcc1.a=$([ -s "$LIBDIR/tcc/libtcc1.a" ] && echo ok || echo MISSING) libgetopt.a=$([ -s "$LIBDIR/libgetopt.a" ] && echo ok || echo MISSING)"

# ── PHASE 4: build tcc-boot0 with tcc-mes (WITH the -I ${PREFIX}/include header fix) ──────────
cd "/build/$TCC_PKG" || { echo "FATAL cd tcc"; exit 0; }
BOOT0_ARGS=(
  -g -v -static -o tcc-boot0 -D BOOTSTRAP=1 -D HAVE_FLOAT=1 -D HAVE_BITFIELD=1 -D HAVE_LONG_LONG=1
  -D HAVE_SETJMP=1 -I . -I "$PREFIX/include" -I "$PREFIX/include/mes" -D TCC_TARGET_X86_64=1
  -D "CONFIG_TCCDIR=\"$LIBDIR/tcc\"" -D "CONFIG_TCC_CRTPREFIX=\"$LIBDIR\"" -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\""
  -D "CONFIG_TCC_LIBPATHS=\"$LIBDIR:$LIBDIR/tcc\"" -D "CONFIG_TCC_SYSINCLUDEPATHS=\"$PREFIX/include/mes\""
  -D "TCC_LIBGCC=\"$LIBDIR/libc.a\"" -D "TCC_LIBTCC1=\"libtcc1.a\"" -D CONFIG_TCCBOOT=1 -D CONFIG_TCC_STATIC=1
  -D CONFIG_USE_LIBGCC=1 -D "TCC_VERSION=\"0.9.26\"" -D ONE_SOURCE=1 -L . -L "$LIBDIR" tcc.c
)
timeout "$STAGE_TIMEOUT" "$TCCMES" "${BOOT0_ARGS[@]}" >"$WORK/boot0-build.out" 2>"$WORK/boot0-build.err"
brc=$?
if [ "$brc" = "0" ] && [ -s tcc-boot0 ]; then
  /usr/bin/cp tcc-boot0 "$TCCBOOT0" && /usr/bin/chmod 755 "$TCCBOOT0"
  /usr/bin/cp tcc-boot0 "$OUTROOT/tcc-boot0.patched"
  emit "DIAG-INFO tcc-boot0 BUILT (rc=$brc, $(/usr/bin/wc -c < tcc-boot0) bytes)"
  BOOT0_OK=1
else
  emit "FATAL tcc-boot0 build FAILED (rc=$brc) >>> $(tail -4 "$WORK/boot0-build.err" 2>/dev/null | tr '\n' '|')"
  BOOT0_OK=0
fi

# ════════════════ BATTERY ════════════════
emit "DIAG-INFO ===== BATTERY ====="
# D2: is tcc-mes's CODEGEN correct (not just non-crashing)? Held against the known-good c+tcc-built tcc-mes.
build_and_run "$TCCMES" "$WORK/hello.c"     42 "D2a-tccmes-hello"
build_and_run "$TCCMES" "$WORK/const4arg.c" 55 "D2b-tccmes-const4arg"
build_and_run "$TCCMES" "$WORK/asmtest.c"    7 "D2c-tccmes-asmtest"

if [ "$BOOT0_OK" = "1" ]; then
  # D1: does tcc-boot0 even start?
  timeout "$RUN_TIMEOUT" "$TCCBOOT0" -version >"$WORK/boot0-version.out" 2>&1
  vrc=$?
  R[D1-boot0-version]="rc=$vrc"
  emit "DIAG-RESULT D1-boot0-version rc=$vrc : $(head -1 "$WORK/boot0-version.out" 2>/dev/null)"
  # D3: tcc-boot0 codegen on NON-asm (hello) vs INLINE-ASM (asmtest) — THE key fork.
  build_and_run "$TCCBOOT0" "$WORK/hello.c"   42 "D3a-boot0-hello"
  build_and_run "$TCCBOOT0" "$WORK/asmtest.c"  7 "D3b-boot0-asmtest"
  # D4: reproduce the real R2 crash — tcc-boot0 -c crt1.c.
  cd "/build/$MES_PKG" || true
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -c -D HAVE_CONFIG_H=1 -I include -I "include/linux/$MES_ARCH" \
    -o "$WORK/crt1-boot0.o" "lib/linux/$MES_ARCH-mes-gcc/crt1.c" >"$WORK/D4-crt1.out" 2>"$WORK/D4-crt1.err"
  d4rc=$?
  R[D4-boot0-crt1]="rc=$d4rc"
  emit "DIAG-RESULT D4-boot0-crt1.c rc=$d4rc ($([ -s "$WORK/crt1-boot0.o" ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -3 "$WORK/D4-crt1.err" 2>/dev/null | tr '\n' '|')"
  cd "/build/$TCC_PKG" || true
else
  emit "DIAG-RESULT D1/D3/D4 SKIPPED — tcc-boot0 did not build"
fi

# ── D5: ARG-COUNT BISECTION + SAVE objects/binaries for local objdump ─────────────────────────
# Pin WHICH arg count first miscompiles (3 fits rdi/rsi/rdx; 4 adds rcx; 5 r8; 6 r9; 7 spills to
# stack) and whether it's CONSTANT-specific. Each f returns sum_{k} k*a_k; called with 1..N.
# const: f3=14 f4=30 f5=55 f6=91 f7=140 ; var (volatile, defeats const-fold): f5v=55.
cd "/build/$TCC_PKG" || true
cat > "$WORK/argc3c.c"  <<'EOF'
int f3(int a,int b,int c){return a+b*2+c*3;}
int main(int ac,char**av,char**ep){return f3(1,2,3);}
EOF
cat > "$WORK/argc4c.c"  <<'EOF'
int f4(int a,int b,int c,int d){return a+b*2+c*3+d*4;}
int main(int ac,char**av,char**ep){return f4(1,2,3,4);}
EOF
cat > "$WORK/argc5c.c"  <<'EOF'
int f5(int a,int b,int c,int d,int e){return a+b*2+c*3+d*4+e*5;}
int main(int ac,char**av,char**ep){return f5(1,2,3,4,5);}
EOF
cat > "$WORK/argc6c.c"  <<'EOF'
int f6(int a,int b,int c,int d,int e,int f){return a+b*2+c*3+d*4+e*5+f*6;}
int main(int ac,char**av,char**ep){return f6(1,2,3,4,5,6);}
EOF
cat > "$WORK/argc7c.c"  <<'EOF'
int f7(int a,int b,int c,int d,int e,int f,int g){return a+b*2+c*3+d*4+e*5+f*6+g*7;}
int main(int ac,char**av,char**ep){return f7(1,2,3,4,5,6,7);}
EOF
cat > "$WORK/argc5v.c"  <<'EOF'
int f5(int a,int b,int c,int d,int e){return a+b*2+c*3+d*4+e*5;}
int main(int ac,char**av,char**ep){volatile int a=1,b=2,c=3,d=4,e=5;return f5(a,b,c,d,e);}
EOF
bis() {  # $1=label $2=expected_rc
  local lab="$1" exp="$2" src="$WORK/$1.c"
  # save the OBJECT (for local objdump of the wrong call/prologue)
  timeout "$UNIT_TIMEOUT" "$TCCMES" -c -o "$OUTROOT/$lab.o" "$src" >"$WORK/$lab.cc.out" 2>"$WORK/$lab.cc.err"
  local crc=$?
  # link + run
  timeout "$UNIT_TIMEOUT" "$TCCMES" -static -o "$OUTROOT/$lab.bin" -L . -L "$LIBDIR" "$src" >>"$WORK/$lab.cc.out" 2>>"$WORK/$lab.cc.err"
  local lrc=$?
  if [ "$lrc" != "0" ] || [ ! -s "$OUTROOT/$lab.bin" ]; then
    emit "DIAG-RESULT BISECT-$lab COMPILE/LINK-FAIL crc=$crc lrc=$lrc >>> $(tail -1 "$WORK/$lab.cc.err" 2>/dev/null)"
    return
  fi
  /usr/bin/chmod 755 "$OUTROOT/$lab.bin"
  timeout "$RUN_TIMEOUT" "$OUTROOT/$lab.bin" >/dev/null 2>"$WORK/$lab.run.err"
  local rrc=$?
  [ "$rrc" = "$exp" ] && emit "DIAG-RESULT BISECT-$lab RUN-OK rc=$rrc (expected $exp)" \
                      || emit "DIAG-RESULT BISECT-$lab RUN-WRONG rc=$rrc (expected $exp) — miscompiled"
}
emit "DIAG-INFO ===== ARG-COUNT BISECTION (objects saved for objdump) ====="
for L in argc3c argc4c argc5c argc6c argc7c argc5v; do
  case "$L" in argc3c) e=14;; argc4c) e=30;; argc5c) e=55;; argc6c) e=91;; argc7c) e=140;; argc5v) e=55;; esac
  bis "$L" "$e"
done
# best-effort tcc-mes -S (don't depend on it for output globs)
timeout "$UNIT_TIMEOUT" "$TCCMES" -S -o "$OUTROOT/argc5c.tccmes.s" "$WORK/argc5c.c" >/dev/null 2>&1 && emit "DIAG-INFO tcc-mes -S produced argc5c.tccmes.s" || emit "DIAG-INFO tcc-mes -S unsupported"

# ── CONSTRUCT BATTERY: enumerate WHICH C-construct classes tcc-mes miscompiles ────────────────
# tcc-boot0 (=tcc.c compiled by tcc-mes) crashes compiling everything, so tcc-mes still miscompiles
# >=1 construct that tcc.c uses but const4arg doesn't. Each tiny program below isolates ONE class
# (header-free; returns 7 iff the construct compiles correctly). FAIL count = is-the-bug-set-FINITE?
# (CONSTRUCT-RESULT <name> OK/WRONG/COMPILE-FAIL). Reuses build_and_run (tcc-mes compiles+links+runs).
emit "DIAG-INFO ===== CONSTRUCT BATTERY (which classes does tcc-mes miscompile?) ====="
cat > "$WORK/cb-structarg.c"   <<'EOF'
struct S { int a; int b; int c; };
int f(struct S s){ return s.a + s.b + s.c; }
int main(int ac,char**av,char**ep){ struct S s; s.a=1; s.b=2; s.c=4; return f(s); }
EOF
cat > "$WORK/cb-structret.c"   <<'EOF'
struct S { int a; int b; };
struct S mk(int x){ struct S s; s.a=x; s.b=x+1; return s; }
int main(int ac,char**av,char**ep){ struct S s = mk(3); return s.a + s.b; }
EOF
cat > "$WORK/cb-structasn.c"   <<'EOF'
struct S { int a; int b; int c; int d; };
int main(int ac,char**av,char**ep){ struct S x; x.a=1; x.b=2; x.c=0; x.d=4; struct S y; y=x; return y.a+y.b+y.c+y.d; }
EOF
cat > "$WORK/cb-funcptr.c"     <<'EOF'
int add(int a,int b){ return a+b; }
int main(int ac,char**av,char**ep){ int (*fp)(int,int) = add; return fp(3,4); }
EOF
cat > "$WORK/cb-switch.c"      <<'EOF'
int f(int x){ switch(x){ case 0: return 1; case 1: return 7; case 2: return 3; default: return 0; } }
int main(int ac,char**av,char**ep){ return f(1); }
EOF
cat > "$WORK/cb-llmul.c"       <<'EOF'
int main(int ac,char**av,char**ep){ long long a=200000LL; long long b=300000LL; long long c=a*b; if (c == 60000000000LL) return 7; return 1; }
EOF
cat > "$WORK/cb-llshift.c"     <<'EOF'
int main(int ac,char**av,char**ep){ long long a=1LL; long long b=a<<34; if (b == 17179869184LL) return 7; return 1; }
EOF
cat > "$WORK/cb-arridx.c"      <<'EOF'
int main(int ac,char**av,char**ep){ int a[5]; a[0]=1;a[1]=2;a[2]=3;a[3]=4;a[4]=5; int i=3; return a[i] + a[i-1]; }
EOF
cat > "$WORK/cb-recur.c"       <<'EOF'
int fib(int n){ if (n < 2) return n; return fib(n-1) + fib(n-2); }
int main(int ac,char**av,char**ep){ return fib(6) - 1; }
EOF
cat > "$WORK/cb-cmpbool.c"     <<'EOF'
int f(int a,int b,int c){ if (a > 0 && b > 0 && c == 0) return 7; return 0; }
int main(int ac,char**av,char**ep){ return f(1,2,0); }
EOF
cat > "$WORK/cb-nestloop.c"    <<'EOF'
int main(int ac,char**av,char**ep){ int s=0; int i; int j; for(i=0;i<7;i++){ for(j=0;j<1;j++){ s=s+1; } } return s; }
EOF
cat > "$WORK/cb-subword.c"     <<'EOF'
int main(int ac,char**av,char**ep){ short s=1000; s = s + 2000; char c=7; if (s == 3000) return c; return 0; }
EOF
cat > "$WORK/cb-ternary.c"     <<'EOF'
int main(int ac,char**av,char**ep){ int x=5; int y=2; int z = (x > y) ? (x + y) : (x - y); return z; }
EOF
cat > "$WORK/cb-ptrstruct.c"   <<'EOF'
struct S { int a; int b; };
void set(struct S *p, int v){ p->a = v; p->b = v + 1; }
int main(int ac,char**av,char**ep){ struct S s; set(&s, 3); return s.a + s.b; }
EOF
cat > "$WORK/cb-globalarr.c"   <<'EOF'
int g[4] = { 1, 2, 3, 1 };
int main(int ac,char**av,char**ep){ return g[0] + g[1] + g[2] + g[3]; }
EOF
# EXTENDED inline-asm output operand — the suspected 5th-bug mechanism (setjmp.c uses this form).
cat > "$WORK/cb-extasm.c"      <<'EOF'
int main(int ac,char**av,char**ep){ int x; asm ("mov $7,%0" : "=r" (x) : ); return x; }
EOF
for cb in cb-structarg cb-structret cb-structasn cb-funcptr cb-switch cb-llmul cb-llshift cb-arridx cb-recur cb-cmpbool cb-nestloop cb-subword cb-ternary cb-ptrstruct cb-globalarr cb-extasm; do
  build_and_run "$TCCMES" "$WORK/$cb.c" 7 "CB-$cb"
done
# compile-vs-link disambiguation: does tcc-boot0 crash COMPILING (no link, no asm)?  hello.c is header-free.
if [ "$BOOT0_OK" = "1" ]; then
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -c -o "$WORK/d6.o" "$WORK/hello.c" >"$WORK/D6.out" 2>"$WORK/D6.err"; d6=$?
  emit "DIAG-RESULT D6-boot0-c-hello rc=$d6 ($([ -s "$WORK/d6.o" ] && echo OBJ-OK || echo NO-OBJ)) — compile-only, no asm, no link"
fi
cat > "$WORK/cb-snpbasic.c" <<'EOF'
int snprintf(char *s, unsigned long n, const char *fmt, ...);
int main(int ac,char**av,char**ep){ char b[32]; snprintf(b,32,"%s%d","x",5); if(b[0]=='x'&&b[1]=='5'&&b[2]==0) return 7; return 1; }
EOF
cat > "$WORK/cb-snpstar.c" <<'EOF'
int snprintf(char *s, unsigned long n, const char *fmt, ...);
int main(int ac,char**av,char**ep){ char b[32]; snprintf(b,32,"%*d",3,5); if(b[0]==' '&&b[1]==' '&&b[2]=='5'&&b[3]==0) return 7; return 1; }
EOF
build_and_run "$TCCMES" "$WORK/cb-snpbasic.c" 7 "CB-cb-snpbasic"
build_and_run "$TCCMES" "$WORK/cb-snpstar.c"  7 "CB-cb-snpstar"
# ── LIBC-STRESS (cb-malloc): the compile path mallocs heavily from instruction 1; the battery never
#    allocates. If tcc-mes miscompiled mes-libc malloc, THIS crashes while everything else passes. ──
cat > "$WORK/cb-malloc.c" <<'EOF'
void *malloc(unsigned long n);
void free(void *p);
int main(int ac,char**av,char**ep){
  int *a = malloc(100 * sizeof(int)); if (!a) return 1;
  int i; int s = 0;
  for (i = 0; i < 100; i++) a[i] = i;
  for (i = 0; i < 100; i++) s = s + a[i];
  free(a);
  return (s == 4950) ? 7 : 2;
}
EOF
build_and_run "$TCCMES" "$WORK/cb-malloc.c" 7 "CB-cb-malloc"
# ── MINIMAL VARIADIC reproducer (cb-vsum): a TINY user variadic fn — its prologue (reg-save-area)
#    + a single va_arg are ~20 instructions, trivially objdump-readable, and isolate the SysV
#    variadic ABI from snprintf/vfprintf's 35KB complexity. Saves vsum.o (small!) + vsum.bin. ──
cat > "$WORK/cb-vsum.c" <<'EOF'
#include <stdarg.h>
int vsum (int n, ...)
{
  va_list ap;
  va_start (ap, n);
  int s = 0;
  int i;
  for (i = 0; i < n; i = i + 1)
    s = s + va_arg (ap, int);
  va_end (ap);
  return s;
}
int main (int ac, char **av, char **ep) { return vsum (3, 2, 2, 3); }
EOF
VAI="-I /build/$MES_PKG/include -I /usr/include -I /usr/include/mes"
timeout "$UNIT_TIMEOUT" "$TCCMES" -c $VAI -o "$OUTROOT/vsum.o" "$WORK/cb-vsum.c" >/dev/null 2>&1 \
  && emit "DIAG-INFO saved vsum.o (minimal variadic — caller+callee prologue+va_arg)" || emit "DIAG-INFO vsum.o save failed"
timeout "$UNIT_TIMEOUT" "$TCCMES" -static $VAI -o "$OUTROOT/vsum.bin" -L . -L "$LIBDIR" "$WORK/cb-vsum.c" >"$WORK/vsum.cc" 2>&1
vcrc=$?
if [ "$vcrc" = "0" ] && [ -s "$OUTROOT/vsum.bin" ]; then
  /usr/bin/chmod 755 "$OUTROOT/vsum.bin"
  timeout "$RUN_TIMEOUT" "$OUTROOT/vsum.bin" >/dev/null 2>"$WORK/vsum.run.err"; vrrc=$?
  [ "$vrrc" = "7" ] && emit "DIAG-RESULT CB-cb-vsum RUN-OK rc=$vrrc (minimal user-variadic WORKS — bug is snprintf-specific?!)" \
                    || emit "DIAG-RESULT CB-cb-vsum RUN-WRONG rc=$vrrc (expected 7 — MINIMAL variadic ABI broken; tiny vsum.o/.bin saved for objdump)"
else
  emit "DIAG-RESULT CB-cb-vsum COMPILE-FAIL rc=$vcrc >>> $(tail -2 "$WORK/vsum.cc" 2>/dev/null | tr '\n' '|')"
fi
# ── LOCATOR: WHERE in the compile does tcc-boot0 die? (phase bisection + verbose) ──
if [ "$BOOT0_OK" = "1" ]; then
  printf 'int x;\n' > "$WORK/glob.c"; : > "$WORK/empty.c"
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -E "$WORK/hello.c"        >"$WORK/locE.out"   2>"$WORK/locE.err";   emit "DIAG-RESULT LOC-boot0-E-preprocess rc=$? ($(/usr/bin/wc -l < "$WORK/locE.out" 2>/dev/null) lines out)"
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -c -o "$WORK/e.o" "$WORK/empty.c" >"$WORK/locEm.out" 2>"$WORK/locEm.err"; emit "DIAG-RESULT LOC-boot0-c-empty rc=$? ($([ -s "$WORK/e.o" ] && echo OBJ-OK || echo NO-OBJ))"
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -c -o "$WORK/g.o" "$WORK/glob.c"  >"$WORK/locG.out" 2>"$WORK/locG.err"; emit "DIAG-RESULT LOC-boot0-c-globalonly rc=$? ($([ -s "$WORK/g.o" ] && echo OBJ-OK || echo NO-OBJ))"
  timeout "$UNIT_TIMEOUT" "$TCCBOOT0" -vv -c -o "$WORK/v.o" "$WORK/hello.c" >"$WORK/locV.out" 2>"$WORK/locV.err"; emit "DIAG-RESULT LOC-boot0-vv-c-hello rc=$? — stderr-tail >>> $(tail -3 "$WORK/locV.err" 2>/dev/null | tr '\n' '|')  stdout-tail >>> $(tail -3 "$WORK/locV.out" 2>/dev/null | tr '\n' '|')"
fi
# ── VARARG FORENSICS: save the actual machine code of a variadic call (both sides) for objdump ──
# snpbasic.o = the CALLER (main's snprintf call: %al setup + arg marshalling, compiled by tcc-mes).
# unified-libc.o = the CALLEE (snprintf/vfprintf va_arg handling, compiled by tcc-mes). objdump -dr
# both locally to SEE whether the bug is the call setup (%al/args) or the libc va_arg side.
cd "/build/$TCC_PKG" 2>/dev/null || true
timeout "$UNIT_TIMEOUT" "$TCCMES" -c -o "$OUTROOT/snpbasic.o" "$WORK/cb-snpbasic.c" >/dev/null 2>&1 \
  && emit "DIAG-INFO saved snpbasic.o (caller-side variadic call)" || emit "DIAG-INFO snpbasic.o save failed"
[ -f "$WORK/CB-cb-snpbasic.bin" ] && /usr/bin/cp "$WORK/CB-cb-snpbasic.bin" "$OUTROOT/snpbasic.bin"
[ -f "/build/$MES_PKG/unified-libc.o" ] && /usr/bin/cp "/build/$MES_PKG/unified-libc.o" "$OUTROOT/unified-libc.o" \
  && emit "DIAG-INFO saved unified-libc.o (callee-side snprintf/vfprintf, $(/usr/bin/wc -c < "$OUTROOT/unified-libc.o") bytes)"

# GUARANTEE every output glob matches >=1 file: copy logs as *.log (objects/.bin from bisection; tcc-* from tcc-mes).
for f in "$WORK"/mescc.err "$WORK"/rows.txt "$WORK"/tccmes-version.out "$WORK"/boot0-build.err; do
  [ -f "$f" ] && /usr/bin/cp "$f" "$OUTROOT/$(/usr/bin/basename "$f").log"
done

# ── MANIFEST + VERDICT ────────────────────────────────────────────────────────────────────────
{
  echo "================ tcc-boot0-diag RESULT MATRIX ================"
  echo "host: $(/usr/bin/uname -a 2>/dev/null)"
  echo "tcc-mes -version: $(head -1 "$WORK/tccmes-version.out" 2>/dev/null)"
  echo "arena: MES_ARENA=$MES_ARENA == MES_MAX_ARENA (no-growth)"
  echo "----- battery rows (also greppable on stdout) -----"
  /usr/bin/cat "$WORK/rows.txt" 2>/dev/null | /usr/bin/grep -E 'DIAG-RESULT|FATAL' || true
  echo "-------------------------------------------------------------"
  echo "MATRIX:"
  for k in D2a-tccmes-hello D2b-tccmes-const4arg D2c-tccmes-asmtest D1-boot0-version D3a-boot0-hello D3b-boot0-asmtest D4-boot0-crt1; do
    printf '  %-26s %s\n' "$k" "${R[$k]:-(unset)}"
  done
  echo "-------------------------------------------------------------"
  echo "VERDICT LOGIC:"
  echo " * D3a OK + D3b CRASH        => bug is the INLINE ASSEMBLER (i386-asm.c) in tcc-boot0."
  echo " * D2c OK + D3b CRASH        => tcc-mes asm-path fine; tcc-mes MISCOMPILED i386-asm.c into boot0."
  echo " * D2a OK + D2b WRONG        => >=4-arg / 16B CValue-union swap corrupts CONSTANT args."
  echo " * D2a FAIL                  => tcc-mes codegen/libc.a broken on simple C (deeper)."
  echo " * D2*+D3a OK, D4 CRASH only => crt1.c-specific construct (mem-deref (%rax) / call) in the asm."
  echo "-------------------------------------------------------------"
  echo "ARTIFACTS (gs://minimalmertic-sign-staging/tcc-boot0-diag-a/usr/share/tcc-boot0-diag/):"
  for f in "$OUTROOT"/*; do [ "$f" = "$MANIFEST" ] && continue; printf '  %-30s %s bytes\n' "$(basename "$f")" "$(/usr/bin/wc -c < "$f" 2>/dev/null || echo 0)"; done
  echo "============================================================="
} | tee "$MANIFEST"

echo "DIAG-INFO manifest -> $MANIFEST"
exit 0
