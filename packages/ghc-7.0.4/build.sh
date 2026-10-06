#!/bin/bash
# ghc-7.0.4 booted by ghc-6.10.4: the first registerised rung (x86_64 native code generator). Its build system wants
# GNU make 3.82 (4.x reorders its rule evaluation), built here from the pinned tarball. Phases: P0 preconditions,
# P1 wrappers + make, P2 configure + build, P3 gate, P4 install, P5 gate on the installed layout.
set -euo pipefail
trap 'echo "ghc-7.0.4: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
V=7.0.4
PREFIX=/usr/lib/ghc-7.0.4
DST="${OUTPUT_DIR}${PREFIX}"
LIBD="$DST/lib/ghc-$V"
TOPDIR="$PREFIX/lib/ghc-$V"
BOOTDIR=/usr/lib/ghc-6.10.4/bin
BUILDROOT=$PWD
BIN=$BUILDROOT/bin
TREE=$BUILDROOT/ghc-$V
export HOME=$BUILDROOT/home; mkdir -p $HOME   # ghc-pkg reads $HOME
export TMPDIR=$BUILDROOT/tmp; mkdir -p $TMPDIR
export TAR_OPTIONS=--no-same-owner   # the build system untars the bundled libffi itself

# --- C toolchain. x86_64: the bedrock gcc against the versioned glibc sysroot (as every rung of the GHC ladder);
# aarch64: the toolchain gcc, itself built from the hex0 seed, as is
if [ "$(uname -m)" = x86_64 ]; then
  SR=/usr/lib/glibc-bedrock-2.42; LOADER=$SR/lib/ld-linux-x86-64.so.2
  [ -e $SR/lib/libc.so ] && [ -e $LOADER ] || { echo "ghc-7.0.4: glibc sysroot missing at $SR" >&2; exit 1; }
  mkdir -p $BIN/fixlib
  # the sysroot's libc.so is a linker script with staging paths; regenerate it
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@$SR/lib/\1@g" $SR/lib/libc.so > $BIN/fixlib/libc.so
  grep -q '/build/output' $BIN/fixlib/libc.so && { echo "ghc-7.0.4: libc.so fixup failed" >&2; exit 1; }
  # gcc (and cc): the first gcc on PATH that is not one of these wrappers (each rung ships one), given the sysroot's headers and, when linking, its
  # libraries and loader ahead of /usr/lib, where the toolchain glibc also lives
  cat > $BIN/gcc <<EOF
#!/bin/sh
# sysroot-gcc-wrapper (every rung ships one; they skip each other by this line)
G=; IFS=:; for d in \$PATH; do [ -x "\$d/gcc" ] || continue; grep -q 'sysroot-gcc-wrapper' "\$d/gcc" 2>/dev/null && continue; G=\$d/gcc; break; done; unset IFS
[ -n "\$G" ] || { echo "gcc wrapper: no gcc on PATH" >&2; exit 127; }
GI=\$("\$G" -print-file-name=include)
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "\$G" -nostdinc -isystem "\$GI" -isystem $SR/include -isystem /usr/include "\$@" ;; esac; done
exec "\$G" -nostdinc -isystem "\$GI" -isystem $SR/include -isystem /usr/include "\$@" -L$BIN/fixlib -B$SR/lib -L$SR/lib -L/usr/lib -Wl,--dynamic-linker=$LOADER -Wl,-rpath,$SR/lib:/usr/lib -Wl,--build-id=none
EOF
  chmod 0755 $BIN/gcc; ln -sf gcc $BIN/cc
fi
mkdir -p $BIN; export PATH=$BIN:$PATH
# mhs and old build scripts call cc; the aarch64 toolchain ships only gcc
command -v cc > /dev/null || ln -s "$(command -v gcc)" $BIN/cc
# --- P0 ---
[ -x $BOOTDIR/ghc ] && [ -x $BOOTDIR/ghc-pkg ] || { echo "ghc-7.0.4: no boot compiler at $BOOTDIR (ghc-6.10.4)" >&2; exit 1; }
$BOOTDIR/ghc --version 2>&1 | grep -q 'version 6.10.4' || { echo "ghc-7.0.4: boot compiler is not 6.10.4" >&2; exit 1; }
$BOOTDIR/ghc-pkg list > /dev/null || { echo "ghc-7.0.4: boot ghc-pkg cannot list its packages" >&2; exit 1; }
[ -f ghc-$V-src.tar.bz2 ] && [ -f make-3.82.tar.bz2 ] || { echo "ghc-7.0.4: source absent" >&2; exit 1; }
[ -f /usr/include/gmp.h ] && [ -f /usr/include/curses.h ] || { echo "ghc-7.0.4: gmp.h or curses.h missing" >&2; exit 1; }

# --- P1 wrappers, found through PATH (configure's --with-gcc is baked into the compiler by name, so they ship in P4) ---
cat > $BIN/gcc89 <<'EOF'
#!/bin/sh
exec gcc -std=gnu89 -fcommon -fno-strict-aliasing -Wno-implicit-int -Wno-implicit-function-declaration \
  -Wno-int-conversion -Wno-incompatible-pointer-types -no-pie "$@"
EOF
# the compiler's cpp (-pgmP): gcc -E splices backslash-newline even with -traditional, destroying Haskell string gaps.
# Protect a backslash whose next line opens with one (a \002 marker, stripped afterwards) on non-directive lines;
# the temporary copy sits beside the input so relative #includes resolve; line markers point back at the real file.
cat > $BIN/cpp-gap <<'EOF'
#!/bin/bash
args=("$@"); out=; in_i=-1
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = "-o" ] && out=${args[$((i + 1))]}
  [ "${args[$i]}" = "-x" ] && [ "${args[$((i + 1))]:-}" = "c" ] && in_i=$((i + 2))
done
[ $in_i -ge 0 ] || exec gcc89 -E -undef -traditional "$@"
in=${args[$in_i]}; tmp=$(mktemp "$(dirname "$in")/.cppgap.XXXXXX")
perl -e '@l = <>; $d = 0; for $i (0 .. $#l) { $_ = $l[$i]; $d = 1 if /^\s*#/; if ($d) { $d = /\\[ \t]*\r?\n$/ ? 1 : 0 } elsif ($i < $#l && $l[$i + 1] =~ /^\s*\\/) { s/\\([ \t]*\r?\n)$/\\\002$1/ } print }' "$in" > "$tmp"
args[$in_i]=$tmp
gcc89 -E -undef -traditional "${args[@]}"; rc=$?
[ -n "$out" ] && [ -f "$out" ] && T="$tmp" I="$in" perl -pi -e 's/\002//g; s/\Q$ENV{T}\E/$ENV{I}/g' "$out"
rm -f "$tmp"; exit $rc
EOF
chmod 0755 $BIN/gcc89 $BIN/cpp-gap
# make 3.82: -fcommon (make.h defines stack_limit in every object); the bundled glob calls glibc-internal
# __alloca/__stat, which glibc no longer exports. glob.c stays as shipped.
mkdir -p $BUILDROOT/make-3.82; tar xjf make-3.82.tar.bz2 -C $BUILDROOT/make-3.82 --strip-components=1
( cd $BUILDROOT/make-3.82 && CC="gcc89 -fcommon" CPPFLAGS="-D__alloca=__builtin_alloca -D__stat=stat" ./configure $( [ "$(uname -m)" = aarch64 ] && echo --build=aarch64-unknown-linux-gnu --host=aarch64-unknown-linux-gnu ) --prefix=$BUILDROOT/make382 > configure.log 2>&1 && make > make.log 2>&1 && make install > install.log 2>&1 ) \
  || { tail -10 $BUILDROOT/make-3.82/make.log >&2; echo "ghc-7.0.4: make 3.82 did not build" >&2; exit 1; }
MK=$BUILDROOT/make382/bin/make
$MK --version | grep -q 'GNU Make 3.82' || { echo "ghc-7.0.4: wrong make" >&2; exit 1; }

# --- P2 configure + build ---
mkdir -p $TREE; tar xjf ghc-$V-src.tar.bz2 -C $TREE --strip-components=1 --no-same-owner
cd $TREE
# GMP >= 6.2 initialises an mpz lazily (no limb allocation); integer-gmp recovers the result ByteArray# from the limb
# pointer unconditionally, so a zero-valued Integer would point into libgmp's data: mpz_init2(x, 64) allocates a limb
GW=libraries/integer-gmp/cbits/gmp-wrappers.cmm
sed -i 's/__gmpz_init(\([^)]*\))/__gmpz_init2(\1, 64)/g' $GW
grep -q '__gmpz_init2(' $GW && ! grep -q '__gmpz_init(' $GW || { echo "ghc-7.0.4: gmp-wrappers fix did not apply" >&2; exit 1; }
# aarch64: 2008-era platform knowledge throughout. The tree and five libraries carry config.guess copies that cannot name
# the host (configure needs a guess that succeeds, and no --build: it takes the platform from the boot's --info);
# configure's CPU table and arch whitelist lack aarch64; the bundled libffi 3.0.9 has no aarch64 port (3.5.2 builds in a
# host-named subdirectory, where the rts and libffi makefiles are pointed)
if [ "$(uname -m)" = aarch64 ]; then
  D=aarch64-unknown-linux-gnu
  for g in $(find . -name config.guess); do cp $BUILDROOT/gnu-config-config.guess $g; cp $BUILDROOT/gnu-config-config.sub $(dirname $g)/config.sub; chmod +x $g $(dirname $g)/config.sub; done
  perl -0pi -e 's/\n  arm\*\)\n    (\w+)="arm"\n    ;;/\n  aarch64*)\n    $1="aarch64"\n    ;;\n  arm*)\n    $1="arm"\n    ;;/g' configure
  sed -i 's/^    alpha|arm|hppa|hppa1_1|i386|ia64|/    aarch64|alpha|arm|hppa|hppa1_1|i386|ia64|/' configure
  [ "$(grep -c 'aarch64\*)' configure)" = 3 ] && grep -q '^    aarch64|alpha|arm|' configure || { echo "ghc-7.0.4: configure platform tables not patched" >&2; exit 1; }
  rm ghc-tarballs/libffi/libffi-3.0.9.tar.gz; cp $BUILDROOT/libffi-3.5.2.tar.gz ghc-tarballs/libffi/
  sed -i "s|libffi/build/include|libffi/build/$D/include|g" rts/ghc.mk libffi/ghc.mk
  sed -i "s|cd libffi/build \&\& ./libtool|cd libffi/build/$D \&\& ./libtool|; s|build/libtool|build/$D/libtool|g; s|libffi/build/.libs|libffi/build/$D/.libs|; /libffi.selinux-detection/d" libffi/ghc.mk
  grep -q "libffi/build/$D/include" rts/ghc.mk && grep -q "cd libffi/build/$D && ./libtool" libffi/ghc.mk || { echo "ghc-7.0.4: libffi rules not repointed" >&2; exit 1; }
fi
CC=gcc89 ./configure --prefix=$PREFIX --with-ghc=$BOOTDIR/ghc --with-ghc-pkg=$BOOTDIR/ghc-pkg --with-gcc=gcc89 > configure.log 2>&1 || { tail -20 configure.log >&2; echo "ghc-7.0.4: configure failed" >&2; exit 1; }
cat > mk/build.mk <<'EOF'
HADDOCK_DOCS        = NO
BUILD_DOCBOOK_HTML  = NO
BUILD_DOCBOOK_PS    = NO
BUILD_DOCBOOK_PDF   = NO
GhcLibWays          = v
SplitObjs           = NO
GhcWithInterpreter  = NO
# no debug RTS way: its unregisterised-style frame-pointer code does not assemble on x86_64
GhcRTSWays          = thr
# stage 1 runs on 6.10's cpp, which mangles string gaps
SRC_HC_OPTS         = -O -H64m -pgmP cpp-gap
GhcStage1HcOpts     = -O
GhcStage2HcOpts     = -O
GhcLibHcOpts        = -O
EOF
# aarch64 has no native code generator before 9.2: unregisterised, without the threaded RTS (it needs a real BaseReg)
[ "$(uname -m)" = aarch64 ] && printf 'GhcUnregisterised    = YES\nGhcWithNativeCodeGen = NO\nGhcRTSWays           =\nGhcNotThreaded       = YES\n' >> mk/build.mk
$MK > all.log 2>&1 || { grep -aiE 'error:|\*\*\*|panic|Segmentation|not in scope|parse error' all.log | grep -v warning | head -12 >&2; echo "ghc-7.0.4: make failed" >&2; exit 1; }
G=$TREE/inplace/bin/ghc-stage2
$G --version 2>&1 | grep -q "version $V" || { echo "ghc-7.0.4: stage 2 compiler does not report $V" >&2; exit 1; }

# --- P3 gate: programs through stage 2 against recorded outputs ---
T=$BUILDROOT/test; mkdir -p $T; cd $T
printf 'main = putStrLn "hello from ghc 7.0.4"\n' > hello.hs; echo 'hello from ghc 7.0.4' > hello.expected
cat > num.hs <<'EOF'
main = do
  print (product [1..25] :: Integer)
  print (2^100 `div` 3 :: Integer, gcd (2^64) (6^30) :: Integer, (-7) `divMod` (2 :: Integer))
  print (maxBound :: Int, toInteger (maxBound :: Int) + 1)
  print (sqrt 2 :: Double, 1/3 :: Double, decodeFloat (1.5 :: Double), 0.1 + 0.2 :: Float)
  print (sum (map fromIntegral [1..100000 :: Int]) :: Double, length (show (2^4096 :: Integer)))
EOF
cat > num.expected <<'EOF'
15511210043330985984000000
(422550200076076467165567735125,1073741824,(-4,1))
(9223372036854775807,9223372036854775808)
(1.4142135623730951,0.3333333333333333,(6755399441055744,-52),0.3)
(5.00005e9,1234)
EOF
# zero-valued Integers through the GMP path (the lazy-init bug's symptom was a crash here)
printf 'main :: IO ()\nmain = do\n  let zs = [ (2 ^ (100 :: Int) + toInteger i) - (2 ^ (100 :: Int) + toInteger i) | i <- [1 .. 300000 :: Int] ]\n  print (sum zs, length (show (product [1 .. 3000 :: Integer])))\n' > gmpzero.hs
echo '(0,9131)' > gmpzero.expected
for p in hello num gmpzero; do
  $G -O -rtsopts -o $p $p.hs > $p.log 2>&1 || { tail -15 $p.log >&2; echo "ghc-7.0.4: stage 2 could not compile $p.hs" >&2; exit 1; }
  ./$p +RTS -K256m -RTS > $p.out 2>&1
  cmp -s $p.out $p.expected || { diff $p.expected $p.out | head -8 >&2; echo "ghc-7.0.4: $p output differs" >&2; exit 1; }
done

# --- P4 install ---
cd $TREE
$MK install DESTDIR=$OUTPUT_DIR > install.log 2>&1 || { tail -20 install.log >&2; echo "ghc-7.0.4: make install failed" >&2; exit 1; }
# the C compiler wrappers the installed compiler runs, with the regenerated libc.so beside them
install -m 0755 $BIN/gcc89 $BIN/cpp-gap "$DST/bin/"
if [ -f $BIN/gcc ]; then install -m 0755 $BIN/gcc "$DST/bin/"; ln -sf gcc "$DST/bin/cc"
  mkdir -p "$DST/lib"; cp -a $BIN/fixlib "$DST/lib/fixlib"; sed -i "s|$BIN/fixlib|$PREFIX/lib/fixlib|" "$DST/bin/gcc"; fi
# the installed wrappers name the C compiler as configured (gcc89): they find it beside themselves
for w in "$DST"/bin/*; do
  [ -f "$w" ] && [ "$(head -c 2 "$w")" = '#!' ] && grep -q 'exedir=' "$w" && sed -i "2i PATH=$PREFIX/bin:\$PATH; export PATH" "$w"
done
grep -q "PATH=$PREFIX/bin" "$DST/bin/ghc-$V" || { echo "ghc-7.0.4: the ghc wrapper did not get its PATH" >&2; exit 1; }
# `recache` writes package.cache in readdir order; registering every conf into a fresh db, sorted, gives a cache that
# does not depend on the filesystem
OLDDB="$LIBD/package.conf.d"; NEWDB="$LIBD/package.conf.d.new"
"$LIBD/ghc-pkg" init "$NEWDB"
for f in $(ls "$OLDDB"/*.conf | LC_ALL=C sort); do
  "$LIBD/ghc-pkg" --global-conf "$NEWDB" register --force "$f" > $BUILDROOT/register.log 2>&1 || { tail -3 $BUILDROOT/register.log >&2; echo "ghc-7.0.4: register $(basename "$f") failed" >&2; exit 1; }
done
[ "$(ls "$NEWDB"/*.conf | wc -l)" = "$(ls "$OLDDB"/*.conf | wc -l)" ] || { echo "ghc-7.0.4: register loop lost a package" >&2; exit 1; }
touch -r "$NEWDB" "$NEWDB/package.cache"
find "$OLDDB" -delete; mv "$NEWDB" "$OLDDB"
# text files only: ELF binaries legitimately embed the build directory
iself() { [ -f "$1" ] && [ "$(head -c 4 "$1" | tr -d '\0')" = $'\x7fELF' ]; }
for f in "$DST"/bin/* "$LIBD"/package.conf.d/*.conf; do iself "$f" || ! grep -q "$BUILDROOT" "$f" || { echo "ghc-7.0.4: build paths survive in $f" >&2; exit 1; }; done

# --- P5 gate on the installed layout: the db pointed at $DST for the duration ---
GATEDB="$LIBD/gate.conf.d"; find "$GATEDB" -delete 2>/dev/null || true; cp -r "$LIBD/package.conf.d" "$GATEDB"
sed -i "s|$PREFIX|$DST|g" "$GATEDB"/*.conf
"$LIBD/ghc-pkg" --global-conf "$GATEDB" recache
cd $T
"$LIBD/ghc" -B"$LIBD" -no-user-package-conf -package-conf "$GATEDB" -O -rtsopts -o gate num.hs -outputdir gate.d > gate.log 2>&1 && ./gate > gate.out 2>&1 || { tail -10 gate.log >&2; echo "ghc-7.0.4: installed compiler failed the gate" >&2; exit 1; }
cmp -s gate.out num.expected || { echo "ghc-7.0.4: installed compiler's output differs" >&2; exit 1; }
INFO=$("$LIBD/ghc" -B"$LIBD" --info)   # captured: grep -q closing the pipe early would fail the pipeline
WANT=NO; [ "$(uname -m)" = aarch64 ] && WANT=YES
echo "$INFO" | grep -q "\"Unregisterised\",\"$WANT\"" || { echo "ghc-7.0.4: Unregisterised is not $WANT" >&2; exit 1; }
find "$GATEDB" -delete
echo "ghc-7.0.4: installed $(du -sh "$DST" | cut -f1) at $PREFIX"
