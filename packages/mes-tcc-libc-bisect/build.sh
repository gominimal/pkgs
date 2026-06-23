#!/usr/bin/env bash
# mes-tcc-libc-bisect harness — see build.ncl for the full rationale.
#
# STAGE-A: faithfully build the amd64 tcc-mes (R2's now-reliable no-growth-arena mescc path:
#          mescc tcc.c -> tcc.s, then mescc-link tcc.s + mes-libc -> tcc-mes), apply BOTH
#          tcctools.c simple-patches so it is byte-identical to the crashing R2 binary, set up
#          include/arch/, and build the reference unified-libc.c. Gate STAGE-B on `tcc-mes -version`.
# STAGE-B: bisect the `tcc-mes -c unified-libc.c` SIGSEGV WITHOUT aborting (set +e):
#          (1) sanity (tiny file) (2) full-TU repro (3) PER-FILE-alone pass (diagnostic AND the
#          split-TU candidate fix) (4) strtold/long-double targeted tests (TEST A/B/C — the H2
#          named suspect) (5) cumulative-prefix coarse ladder + binary search for the minimal
#          crashing N (6) reversed-order ladder (order-independence: H3 vs H2) (7) prove the
#          per-file split-TU fix end-to-end via `tcc-mes -ar`. Emit greppable BISECT-RESULT rows
#          + a final RESULT TABLE to BOTH stdout and the OutputData artifact, then exit 0.
#
# Greppable markers:
#   BISECT-RESULT <case> <OUTCOME> <secs>s rc=<rc> [bytes=<n>] [tip=<file>]   (one per sub-test)
#   BISECT-ERRTAIL <case> >>> <last stderr lines>                            (non-PASS triage)
#   BISECT-INFO  ...                                                         (progress / phases)
#   BISECT-TABLE ...                                                         (final summary rows)
set +e
set -u

# ── constant env (MUST match the production R2 tcc.kaem so STAGE-A reflects the real build) ──
export MES_PREFIX=/usr
export GUILE_LOAD_PATH=/usr/share/mes/mes/module:/usr/share/mes/module:/usr/share/nyacc/module
# Arena: MES_ARENA == MES_MAX_ARENA (NO GROWTH) is MANDATORY — the now-reliable R2 path. Growth
# (ARENA<MAX_ARENA) arms gc_up_arena's overflowing realloc (the now-solved mes-m2 instability).
export MES_STACK=15000000
export MES_ARENA=50000000
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
TCC=$BINDIR/tcc-mes

STAGEA_TIMEOUT=600        # bound the ~250s mescc tcc.c->tcc.s long pole
PERUNIT_TIMEOUT=120       # bound each STAGE-B compile (a crash/timeout can't eat the whole build)

OUTROOT=/build/output/usr/share/mes-tcc-libc-bisect
mkdir -p "$OUTROOT"
MATRIX="$OUTROOT/matrix.txt"
WORK=/build/bisect-logs
OBJDIR=/build/bisect-obj
mkdir -p "$WORK" "$OBJDIR" "$BINDIR" "$LIBDIR"

# ── the 258 libc members, VERBATIM (order + spelling) from tcc.kaem:185 with ${MES_ARCH}=x86_64.
#    These are RELATIVE TO lib/ (the catm CWD). strtold.c (the SOLE long-double user / H2 suspect)
#    is at index 176 (1-based). ──
FILES=(
  "ctype/isalnum.c"
  "ctype/isalpha.c"
  "ctype/isascii.c"
  "ctype/iscntrl.c"
  "ctype/isdigit.c"
  "ctype/isgraph.c"
  "ctype/islower.c"
  "ctype/isnumber.c"
  "ctype/isprint.c"
  "ctype/ispunct.c"
  "ctype/isspace.c"
  "ctype/isupper.c"
  "ctype/isxdigit.c"
  "ctype/tolower.c"
  "ctype/toupper.c"
  "dirent/closedir.c"
  "dirent/__getdirentries.c"
  "dirent/opendir.c"
  "linux/readdir.c"
  "linux/access.c"
  "linux/brk.c"
  "linux/chdir.c"
  "linux/chmod.c"
  "linux/clock_gettime.c"
  "linux/close.c"
  "linux/dup2.c"
  "linux/dup.c"
  "linux/execve.c"
  "linux/fcntl.c"
  "linux/fork.c"
  "linux/fsync.c"
  "linux/fstat.c"
  "linux/_getcwd.c"
  "linux/getdents.c"
  "linux/getegid.c"
  "linux/geteuid.c"
  "linux/getgid.c"
  "linux/getpid.c"
  "linux/getppid.c"
  "linux/getrusage.c"
  "linux/gettimeofday.c"
  "linux/getuid.c"
  "linux/ioctl.c"
  "linux/ioctl3.c"
  "linux/kill.c"
  "linux/link.c"
  "linux/lseek.c"
  "linux/lstat.c"
  "linux/malloc.c"
  "linux/mkdir.c"
  "linux/mknod.c"
  "linux/nanosleep.c"
  "linux/_open3.c"
  "linux/pipe.c"
  "linux/_read.c"
  "linux/readlink.c"
  "linux/rename.c"
  "linux/rmdir.c"
  "linux/setgid.c"
  "linux/settimer.c"
  "linux/setuid.c"
  "linux/signal.c"
  "linux/sigprogmask.c"
  "linux/symlink.c"
  "linux/stat.c"
  "linux/time.c"
  "linux/unlink.c"
  "linux/waitpid.c"
  "linux/wait4.c"
  "linux/x86_64-mes-gcc/_exit.c"
  "linux/x86_64-mes-gcc/syscall.c"
  "linux/x86_64-mes-gcc/_write.c"
  "math/ceil.c"
  "math/fabs.c"
  "math/floor.c"
  "mes/abtod.c"
  "mes/abtol.c"
  "mes/__assert_fail.c"
  "mes/assert_msg.c"
  "mes/__buffered_read.c"
  "mes/__init_io.c"
  "mes/cast.c"
  "mes/dtoab.c"
  "mes/eputc.c"
  "mes/eputs.c"
  "mes/fdgetc.c"
  "mes/fdgets.c"
  "mes/fdputc.c"
  "mes/fdputs.c"
  "mes/fdungetc.c"
  "mes/globals.c"
  "mes/itoa.c"
  "mes/ltoab.c"
  "mes/ltoa.c"
  "mes/__mes_debug.c"
  "mes/mes_open.c"
  "mes/ntoab.c"
  "mes/oputc.c"
  "mes/oputs.c"
  "mes/search-path.c"
  "mes/ultoa.c"
  "mes/utoa.c"
  "posix/alarm.c"
  "posix/buffered-read.c"
  "posix/execl.c"
  "posix/execlp.c"
  "posix/execv.c"
  "posix/execvp.c"
  "posix/getcwd.c"
  "posix/getenv.c"
  "posix/isatty.c"
  "posix/mktemp.c"
  "posix/open.c"
  "posix/pathconf.c"
  "posix/raise.c"
  "posix/sbrk.c"
  "posix/setenv.c"
  "posix/sleep.c"
  "posix/unsetenv.c"
  "posix/wait.c"
  "posix/write.c"
  "stdio/clearerr.c"
  "stdio/fclose.c"
  "stdio/fdopen.c"
  "stdio/feof.c"
  "stdio/ferror.c"
  "stdio/fflush.c"
  "stdio/fgetc.c"
  "stdio/fgets.c"
  "stdio/fileno.c"
  "stdio/fopen.c"
  "stdio/fprintf.c"
  "stdio/fputc.c"
  "stdio/fputs.c"
  "stdio/fread.c"
  "stdio/freopen.c"
  "stdio/fscanf.c"
  "stdio/fseek.c"
  "stdio/ftell.c"
  "stdio/fwrite.c"
  "stdio/getc.c"
  "stdio/getchar.c"
  "stdio/perror.c"
  "stdio/printf.c"
  "stdio/putc.c"
  "stdio/putchar.c"
  "stdio/remove.c"
  "stdio/snprintf.c"
  "stdio/sprintf.c"
  "stdio/sscanf.c"
  "stdio/ungetc.c"
  "stdio/vfprintf.c"
  "stdio/vfscanf.c"
  "stdio/vprintf.c"
  "stdio/vsnprintf.c"
  "stdio/vsprintf.c"
  "stdio/vsscanf.c"
  "stdlib/abort.c"
  "stdlib/abs.c"
  "stdlib/alloca.c"
  "stdlib/atexit.c"
  "stdlib/atof.c"
  "stdlib/atoi.c"
  "stdlib/atol.c"
  "stdlib/calloc.c"
  "stdlib/__exit.c"
  "stdlib/exit.c"
  "stdlib/free.c"
  "stdlib/mbstowcs.c"
  "stdlib/puts.c"
  "stdlib/qsort.c"
  "stdlib/realloc.c"
  "stdlib/strtod.c"
  "stdlib/strtof.c"
  "stdlib/strtol.c"
  "stdlib/strtold.c"
  "stdlib/strtoll.c"
  "stdlib/strtoul.c"
  "stdlib/strtoull.c"
  "string/bcmp.c"
  "string/bcopy.c"
  "string/bzero.c"
  "string/index.c"
  "string/memchr.c"
  "string/memcmp.c"
  "string/memcpy.c"
  "string/memmem.c"
  "string/memmove.c"
  "string/memset.c"
  "string/rindex.c"
  "string/strcat.c"
  "string/strchr.c"
  "string/strcmp.c"
  "string/strcpy.c"
  "string/strcspn.c"
  "string/strdup.c"
  "string/strerror.c"
  "string/strlen.c"
  "string/strlwr.c"
  "string/strncat.c"
  "string/strncmp.c"
  "string/strncpy.c"
  "string/strpbrk.c"
  "string/strrchr.c"
  "string/strspn.c"
  "string/strstr.c"
  "string/strupr.c"
  "stub/atan2.c"
  "stub/bsearch.c"
  "stub/chown.c"
  "stub/__cleanup.c"
  "stub/cos.c"
  "stub/ctime.c"
  "stub/exp.c"
  "stub/fpurge.c"
  "stub/freadahead.c"
  "stub/frexp.c"
  "stub/getgrgid.c"
  "stub/getgrnam.c"
  "stub/getlogin.c"
  "stub/getpgid.c"
  "stub/getpgrp.c"
  "stub/getpwnam.c"
  "stub/getpwuid.c"
  "stub/gmtime.c"
  "stub/ldexp.c"
  "stub/localtime.c"
  "stub/log.c"
  "stub/mktime.c"
  "stub/modf.c"
  "stub/mprotect.c"
  "stub/pclose.c"
  "stub/popen.c"
  "stub/pow.c"
  "stub/putenv.c"
  "stub/rand.c"
  "stub/realpath.c"
  "stub/rewind.c"
  "stub/setbuf.c"
  "stub/setgrent.c"
  "stub/setlocale.c"
  "stub/setvbuf.c"
  "stub/sigaction.c"
  "stub/sigaddset.c"
  "stub/sigblock.c"
  "stub/sigdelset.c"
  "stub/sigemptyset.c"
  "stub/sigsetmask.c"
  "stub/sin.c"
  "stub/sys_siglist.c"
  "stub/system.c"
  "stub/sqrt.c"
  "stub/strftime.c"
  "stub/times.c"
  "stub/ttyname.c"
  "stub/umask.c"
  "stub/utime.c"
  "x86_64-mes-gcc/setjmp.c"
)
NFILES=${#FILES[@]}
# LIBFILES = the same list prefixed with lib/ (paths relative to the MES_PKG root, the STAGE-B CWD).
LIBFILES=( "${FILES[@]/#/lib/}" )

# ── classify one tcc-mes compile's exit into a bucket using rc + stderr signature + .o presence ──
classify() {
  # $1=rc  $2=stderr-file  $3=expected-.o (may be empty)
  local rc="$1" errf="$2" obj="${3:-}"
  if [ "$rc" = "0" ]; then
    if [ -n "$obj" ] && [ ! -s "$obj" ]; then echo "OK-NOOBJ"; return; fi
    echo "OK"; return
  fi
  # mes-libc's abort path is a deliberate NULL write -> the binary self-reports before dying.
  if grep -qiE 'assert fail' "$errf" 2>/dev/null; then echo "ASSERTFAIL/SIGSEGV"; return; fi
  case "$rc" in
    139) echo "SIGSEGV(11)"; return ;;
    134) echo "SIGABRT(6)"; return ;;
    124) echo "TIMEOUT"; return ;;
  esac
  if grep -qiE 'signal number = 11|abnormal termination' "$errf" 2>/dev/null; then echo "SIGSEGV(11)"; return; fi
  echo "OTHER($rc)"
}

# ── compile one source file with tcc-mes (-c), bounded, tolerant; emit a BISECT-RESULT row. ──
# Returns OUTCOME on stdout via the global LAST_OUTCOME; the CWD must be the MES_PKG root.
compile_unit() {
  # $1=case-label  $2=source.c (relative to CWD)  $3=output.o  [$4=extra note for the row]
  local label="$1" src="$2" obj="$3" note="${4:-}"
  local safe="${label//\//_}"   # blocker fix: per-file labels like pf-lib/ctype/x.c contain slashes -> sanitize for filenames
  local errf="$WORK/${safe}.err"
  rm -f "$obj" "$errf"
  local bytes=0; [ -f "$src" ] && bytes=$(wc -c < "$src" 2>/dev/null || echo 0)
  local t0=$SECONDS
  timeout "$PERUNIT_TIMEOUT" "$TCC" -c -D HAVE_CONFIG_H=1 -I include -I "include/linux/$MES_ARCH" \
    -o "$obj" "$src" >"$WORK/${safe}.out" 2>"$errf"
  local rc=$?
  local secs=$((SECONDS - t0))
  LAST_OUTCOME=$(classify "$rc" "$errf" "$obj")
  echo "BISECT-RESULT $label $LAST_OUTCOME ${secs}s rc=$rc bytes=$bytes $note"
  case "$LAST_OUTCOME" in
    OK) : ;;
    *) echo "BISECT-ERRTAIL $label >>> $(tail -3 "$errf" 2>/dev/null | tr '\n' '|')" ;;
  esac
}

# concat a list of lib/-relative files into a target .c (faithful to the `catm` concatenation)
make_tu() { local out="$1"; shift; cat "$@" > "$out" 2>/dev/null; }

# ════════════════════════════════════════════════════════════════════════════════════════════
# STAGE-A — build tcc-mes faithfully (no-growth arena, the now-reliable R2 path)
# ════════════════════════════════════════════════════════════════════════════════════════════
echo "BISECT-INFO STAGE-A begin: build tcc-mes (mescc no-growth arena 50M/50M)"
echo "BISECT-INFO mes-m2: $($MES --version 2>&1 | head -1 || true)"

# Apply BOTH tcctools.c simple-patches (R0.5's /usr/bin/simple-patch) so tcc-mes == the crashing
# R2 binary (tcctools.c is compiled into it via ONE_SOURCE=1). Tolerate-absent: warn, don't abort.
if command -v simple-patch >/dev/null 2>&1; then
  simple-patch "/build/$TCC_PKG/tcctools.c" /build/remove-fileopen.before /build/remove-fileopen.after \
    && simple-patch "/build/$TCC_PKG/tcctools.c" /build/addback-fileopen.before /build/addback-fileopen.after \
    && echo "BISECT-INFO tcctools.c simple-patches applied" \
    || echo "BISECT-INFO WARN simple-patch failed (tcc-mes may differ from R2 in the -ar fopen path only)"
else
  echo "BISECT-INFO WARN simple-patch not found — skipping tcctools.c patch (non-fatal for -c compiles)"
fi

# empty config.h for both trees (BOOTSTRAP defines arrive via -D)
: > "/build/$TCC_PKG/config.h"
: > "/build/$MES_PKG/include/mes/config.h"

cd "/build/$TCC_PKG" || { echo "BISECT-FATAL cannot cd into tcc tree"; exit 0; }

# the mescc -D argv, byte-faithful to R2 tcc.kaem:137-158. The CONFIG_*/TCC_* string literals MUST
# carry LITERAL double-quotes into mescc; the bash array preserves them (\" inside "..." => ").
MESCC_ARGS=(
  -S
  -o tcc.s
  -I "$INCDIR"
  -D BOOTSTRAP=1
  -D HAVE_LONG_LONG=1
  -I .
  -D TCC_TARGET_X86_64=1
  -D inline=
  -D "CONFIG_TCCDIR=\"$LIBDIR/tcc\""
  -D "CONFIG_SYSROOT=\"/\""
  -D "CONFIG_TCC_CRTPREFIX=\"$LIBDIR\""
  -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\""
  -D "CONFIG_TCC_SYSINCLUDEPATHS=\"$PREFIX/include/mes\""
  -D "TCC_LIBGCC=\"$LIBDIR/libc.a\""
  -D CONFIG_TCC_LIBTCC1_MES=0
  -D CONFIG_TCCBOOT=1
  -D CONFIG_TCC_STATIC=1
  -D CONFIG_USE_LIBGCC=1
  -D "TCC_VERSION=\"0.9.26\""
  -D ONE_SOURCE=1
  tcc.c
)
echo "BISECT-INFO STAGE-A: mescc tcc.c -> tcc.s (no-growth arena, ~250s long pole) ..."
ta0=$SECONDS
timeout "$STAGEA_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- "${MESCC_ARGS[@]}" \
  >"$WORK/stageA-compile.out" 2>"$WORK/stageA-compile.err"
rc_compile=$?
echo "BISECT-INFO STAGE-A mescc compile rc=$rc_compile $((SECONDS-ta0))s ($(wc -l < tcc.s 2>/dev/null || echo 0) lines tcc.s)"
if [ "$rc_compile" != "0" ] || [ ! -s tcc.s ]; then
  echo "BISECT-FATAL STAGE-A mescc tcc.c->tcc.s FAILED (rc=$rc_compile) >>> $(tail -4 "$WORK/stageA-compile.err" 2>/dev/null | tr '\n' '|')"
  { echo "STAGE-A FAILED at mescc tcc.c->tcc.s (rc=$rc_compile) — cannot bisect."; } | tee "$MATRIX"
  exit 0
fi

# link tcc.s + R1's mes-libc -> tcc-mes (MES_PREFIX=/usr makes `-l c+tcc` resolve R1's
# /usr/lib/x86_64-mes/libc+tcc.a; -L $LIBDIR is additive/empty and does NOT supply c+tcc).
echo "BISECT-INFO STAGE-A: mescc-link tcc.s -> tcc-mes ..."
timeout "$STAGEA_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- \
  --base-address 0x08048000 -o tcc-mes -L "$LIBDIR" tcc.s -l c+tcc \
  >"$WORK/stageA-link.out" 2>"$WORK/stageA-link.err"
rc_link=$?
if [ "$rc_link" != "0" ] || [ ! -s tcc-mes ]; then
  echo "BISECT-FATAL STAGE-A link FAILED (rc=$rc_link) >>> $(tail -4 "$WORK/stageA-link.err" 2>/dev/null | tr '\n' '|')"
  { echo "STAGE-A FAILED at mescc link (rc=$rc_link) — cannot bisect."; } | tee "$MATRIX"
  exit 0
fi
cp tcc-mes "$BINDIR/" && chmod 755 "$TCC"

# GATE: tcc-mes must run (-version) before we bisect. If THIS crashes, tcc-mes itself is broken.
"$TCC" -version >"$WORK/version.out" 2>&1
rc_ver=$?
TCC_VERSION_LINE=$(head -1 "$WORK/version.out" 2>/dev/null)
echo "BISECT-INFO STAGE-A tcc-mes -version rc=$rc_ver: $TCC_VERSION_LINE"
if [ "$rc_ver" != "0" ]; then
  echo "BISECT-FATAL tcc-mes -version FAILED (rc=$rc_ver) — the built compiler is broken (H2)."
  { echo "tcc-mes -version FAILED (rc=$rc_ver): $TCC_VERSION_LINE"; } | tee "$MATRIX"
  exit 0
fi

# ── arch headers + reference unified-libc.c (must exist before any libc compile) ──
cd "/build/$MES_PKG" || { echo "BISECT-FATAL cannot cd into mes tree"; exit 0; }
mkdir -p include/arch
cp "include/linux/$MES_ARCH/kernel-stat.h" include/arch/kernel-stat.h
cp "include/linux/$MES_ARCH/signal.h"      include/arch/signal.h
cp "include/linux/$MES_ARCH/syscall.h"     include/arch/syscall.h
echo "BISECT-INFO STAGE-A include/arch/ populated; building reference unified-libc.c ($NFILES files)"
make_tu unified-libc.c "${LIBFILES[@]}"
echo "BISECT-INFO unified-libc.c = $(wc -c < unified-libc.c) bytes / $(wc -l < unified-libc.c) lines"

# ════════════════════════════════════════════════════════════════════════════════════════════
# STAGE-B — bisect the unified-libc.c SIGSEGV (set +e; never abort; classify every subset)
# ════════════════════════════════════════════════════════════════════════════════════════════
echo "BISECT-INFO STAGE-B begin"

# ── probe 1: SANITY — a single tiny file. Expect OK; if THIS crashes, tcc-mes is broken (H2). ──
make_tu "$OBJDIR/tiny.c" lib/ctype/isalnum.c
compile_unit "01-sanity-tiny" "$OBJDIR/tiny.c" "$OBJDIR/tiny.o"
SANITY_OUTCOME="$LAST_OUTCOME"

# ── probe 2: FULL-TU repro — the exact R2 step. Expect SIGSEGV (proves the harness reproduces). ──
compile_unit "02-full-unified" "unified-libc.c" "$OBJDIR/unified.o"
FULL_OUTCOME="$LAST_OUTCOME"

# ── probe 3: PER-FILE-alone pass — the headline experiment (diagnostic AND split-TU candidate
#    FIX). Compile EACH member alone to its own .o. Count crashes; remember which files crash. ──
echo "BISECT-INFO probe3: per-file-alone compile of all $NFILES members"
PERFILE_CRASHES=()
PERFILE_OK=0
for idx in "${!LIBFILES[@]}"; do
  f="${LIBFILES[$idx]}"
  tag=$(echo "$f" | tr '/.' '__')
  obj="$OBJDIR/pf_${tag}.o"
  compile_unit "pf-$f" "$f" "$obj" "(per-file $((idx+1))/$NFILES)" >>"$WORK/perfile.log" 2>&1
  if [ "$LAST_OUTCOME" != "OK" ]; then PERFILE_CRASHES+=("$f:$LAST_OUTCOME"); fi
  [ "$LAST_OUTCOME" = "OK" ] && PERFILE_OK=$((PERFILE_OK+1))
done
# surface the per-file crash rows to the main log too
grep -E 'BISECT-(RESULT|ERRTAIL) pf-' "$WORK/perfile.log" | grep -vE ' OK ' || true
echo "BISECT-INFO probe3 done: $PERFILE_OK/$NFILES compiled OK alone; ${#PERFILE_CRASHES[@]} crashed alone: ${PERFILE_CRASHES[*]:-none}"

# ── probe 4 (H2 named suspect — strtold / long double / x86_64-gen.c assert(0) stubs) ──
# 4A: strtold.c ALONE — predicted SAME assert/SIGSEGV (a ~10-line file can't overflow a buffer).
compile_unit "04A-strtold-alone" "lib/stdlib/strtold.c" "$OBJDIR/strtold.o"
STRTOLD_ALONE="$LAST_OUTCOME"
# 4B: FULL-TU-minus-strtold — predicted OK if strtold is the SOLE trigger (refutes H1 size/count).
MINUS=()
for f in "${LIBFILES[@]}"; do [ "$f" = "lib/stdlib/strtold.c" ] || MINUS+=("$f"); done
make_tu "$OBJDIR/minus_strtold.c" "${MINUS[@]}"
compile_unit "04B-full-minus-strtold" "$OBJDIR/minus_strtold.c" "$OBJDIR/minus_strtold.o"
MINUS_STRTOLD="$LAST_OUTCOME"
# 4C: synthetic long-double one-liners to localize the precise unimplemented x87 path.
printf 'long double r(char*s){return strtod(s,0);}\n'           > "$OBJDIR/ld_ret.c"
printf 'void cb(long double);void z(){cb(1.0L);}\n'             > "$OBJDIR/ld_arg.c"
printf 'long double id(long double x){return x;}\n'            > "$OBJDIR/ld_id.c"
compile_unit "04C1-ld-return-convert" "$OBJDIR/ld_ret.c" "$OBJDIR/ld_ret.o"
compile_unit "04C2-ld-arg-call"       "$OBJDIR/ld_arg.c" "$OBJDIR/ld_arg.o"
compile_unit "04C3-ld-identity"       "$OBJDIR/ld_id.c"  "$OBJDIR/ld_id.o"

# ── probe 5: cumulative-prefix coarse ladder + binary search for the minimal crashing N ──
# Coarse ladder (human-readable). Each prefix = first N members concatenated.
echo "BISECT-INFO probe5: cumulative-prefix coarse ladder"
LADDER=(1 25 50 100 150 175 176 200 "$NFILES")
for N in "${LADDER[@]}"; do
  [ "$N" -le "$NFILES" ] || continue
  make_tu "$OBJDIR/prefix_${N}.c" "${LIBFILES[@]:0:N}"
  compile_unit "05-prefix-N$N" "$OBJDIR/prefix_${N}.c" "$OBJDIR/prefix_${N}.o" "(first $N files)"
done
# Binary search for the minimal crashing prefix N (assumes monotonic: once N crashes, >N crash).
# Converges in ~8 compiles; reports the TIP file FILES[N-1] — EITHER the size threshold OR the
# specific culprit (per-file probe3 disambiguates). Treat anything != OK as "crash".
echo "BISECT-INFO probe5b: binary search for minimal crashing prefix"
lo=1; hi=$NFILES; minN=0; tipfile="none"
# verify the full set crashes before searching (else search is meaningless)
make_tu "$OBJDIR/bs_full.c" "${LIBFILES[@]:0:hi}"
compile_unit "05b-bs-full-N$hi" "$OBJDIR/bs_full.c" "$OBJDIR/bs_full.o"
if [ "$LAST_OUTCOME" = "OK" ]; then
  echo "BISECT-INFO probe5b: full prefix did NOT crash — no threshold to search (skipping)"
else
  while [ "$lo" -le "$hi" ]; do
    mid=$(( (lo + hi) / 2 ))
    make_tu "$OBJDIR/bs_${mid}.c" "${LIBFILES[@]:0:mid}"
    compile_unit "05b-bs-N$mid" "$OBJDIR/bs_${mid}.c" "$OBJDIR/bs_${mid}.o" "(binsearch)"
    if [ "$LAST_OUTCOME" = "OK" ]; then
      lo=$((mid + 1))
    else
      minN=$mid; tipfile="${FILES[$((mid-1))]}"; hi=$((mid - 1))
    fi
  done
  echo "BISECT-INFO probe5b: minimal crashing prefix N=$minN tip=$tipfile"
fi

# ── probe 6: REVERSED-ORDER coarse ladder (order-independence: H3 volume vs H2 specific file).
#    If the crash appears at a similar BYTE size regardless of order => H3; if only when a
#    specific file enters => H2/H1. ──
echo "BISECT-INFO probe6: reversed-order ladder"
REV=()
for ((i=NFILES-1; i>=0; i--)); do REV+=("${LIBFILES[$i]}"); done
for N in 50 100 175 200 "$NFILES"; do
  [ "$N" -le "$NFILES" ] || continue
  make_tu "$OBJDIR/rev_${N}.c" "${REV[@]:0:N}"
  compile_unit "06-rev-prefix-N$N" "$OBJDIR/rev_${N}.c" "$OBJDIR/rev_${N}.o" "(last $N files, reversed)"
done

# ── probe 7: PROVE the per-file split-TU candidate FIX end-to-end. If (nearly) all members
#    compiled OK alone, archive the .o set into a libc.a exactly as the kaem would (`tcc-mes -ar
#    cr`). A clean archive => per-file compilation is a drop-in replacement for the crashing
#    unified `-c`. (Functional proof that boot0 links against it is left to a follow-up rung —
#    flagged in INTERPRETATION.) ──
echo "BISECT-INFO probe7: per-file split-TU fix proof (tcc-mes -ar of the per-file .o set)"
AR_OUTCOME="SKIPPED"
if [ "${#PERFILE_CRASHES[@]}" -eq 0 ]; then
  # collect every per-file object that exists
  shopt -s nullglob
  PFOBJS=( "$OBJDIR"/pf_*.o )
  shopt -u nullglob
  if [ "${#PFOBJS[@]}" -gt 0 ]; then
    rm -f "$OBJDIR/libc_split.a"
    timeout "$PERUNIT_TIMEOUT" "$TCC" -ar cr "$OBJDIR/libc_split.a" "${PFOBJS[@]}" \
      >"$WORK/ar.out" 2>"$WORK/ar.err"
    rc_ar=$?
    if [ "$rc_ar" = "0" ] && [ -s "$OBJDIR/libc_split.a" ]; then
      AR_OUTCOME="OK($(wc -c < "$OBJDIR/libc_split.a") bytes, ${#PFOBJS[@]} members)"
    else
      AR_OUTCOME="FAILED(rc=$rc_ar) >>> $(tail -2 "$WORK/ar.err" 2>/dev/null | tr '\n' '|')"
    fi
  fi
else
  AR_OUTCOME="SKIPPED (${#PERFILE_CRASHES[@]} files crash alone => per-file is NOT a clean fix)"
fi
echo "BISECT-RESULT 07-ar-split-libc $AR_OUTCOME"

# ════════════════════════════════════════════════════════════════════════════════════════════
# FINAL RESULT TABLE — to stdout AND the OutputData artifact
# ════════════════════════════════════════════════════════════════════════════════════════════
{
  echo "================ mes-tcc-libc-bisect RESULT TABLE ================"
  echo "host: $(uname -a 2>/dev/null)"
  echo "tcc-mes: $TCC_VERSION_LINE"
  echo "mes-m2 arena: MES_ARENA=$MES_ARENA MES_MAX_ARENA=$MES_MAX_ARENA (no-growth)  members=$NFILES"
  echo "------------------------------------------------------------------"
  echo "PROBE                         OUTCOME"
  printf 'BISECT-TABLE %-28s %s\n' "01 sanity (tiny isalnum.c)"   "$SANITY_OUTCOME"
  printf 'BISECT-TABLE %-28s %s\n' "02 full unified-libc.c"       "$FULL_OUTCOME"
  printf 'BISECT-TABLE %-28s %s\n' "03 per-file OK count"         "$PERFILE_OK/$NFILES (crashed: ${PERFILE_CRASHES[*]:-none})"
  printf 'BISECT-TABLE %-28s %s\n' "04A strtold.c alone"          "$STRTOLD_ALONE"
  printf 'BISECT-TABLE %-28s %s\n' "04B full minus strtold.c"     "$MINUS_STRTOLD"
  printf 'BISECT-TABLE %-28s %s\n' "05b min crashing prefix N"    "${minN} (tip=${tipfile})"
  printf 'BISECT-TABLE %-28s %s\n' "07 per-file split libc.a"     "$AR_OUTCOME"
  echo "------------------------------------------------------------------"
  echo "(per-probe BISECT-RESULT rows above carry bytes/rc/secs; the prefix ladder + reversed"
  echo " ladder + 04C long-double one-liners are in the BISECT-RESULT stream.)"
  echo "------------------------------------------------------------------"
  echo "INTERPRETATION:"
  echo " * sanity=OK + full=SIGSEGV  => harness reproduces the R2 wall."
  echo " * 04B (full-minus-strtold)=OK  => strtold.c (long double) is the SOLE trigger => H2"
  echo "     (x86_64-gen.c long-double/x87 assert(0) stub, :1313/:2256). FIX: patch strtold.c to"
  echo "     avoid x87 long double on amd64, or implement VT_LDOUBLE in x86_64-gen.c. NOT a split-TU."
  echo " * 04A strtold.c crashes ALONE  => construct-specific (refutes H1 size/buffer overflow)."
  echo " * probe3 ALL OK alone + full crashes + 04B still SIGSEGV  => cumulative within one TU"
  echo "     (H3 mes-libc bump-allocator heap exhaustion OR an H1 section/table growth limit)."
  echo "     If probe7 archives a clean libc.a => SPLIT-TU per-file compile is a drop-in R2 fix"
  echo "     (verify boot0 links it in a follow-up rung). amd64 has NO upstream byte-fixed-point"
  echo "     and mes's own cc.sh already builds libc.a per-file, so split-TU deviates from NOTHING."
  echo " * probe5 SHARP OK->crash at a specific N + probe3 all-OK  => size/count threshold (H1)."
  echo " * probe6 reversed crashes at a SIMILAR byte size  => volume-driven (H3); crashes only"
  echo "     when a specific file enters  => construct-specific (H2/H1)."
  echo " * 04C1/04C2/04C3: whichever long-double one-liner crashes pins the exact x87 stub path."
  echo "=================================================================="
} | tee "$MATRIX"

echo "BISECT-INFO matrix written to $MATRIX"
exit 0
