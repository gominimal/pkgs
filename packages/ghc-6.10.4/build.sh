#!/bin/bash
# ghc-6.10.4 booted by ghc-6.6.1: stage 1 (compiled by 6.6.1) builds the libraries and stage 2; stage 2's tree is
# what gets installed. Phases: P0 preconditions, P1 wrappers, P2 configure + build, P3 gate, P4 install.
set -euo pipefail
trap 'echo "ghc-6.10.4: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
V=6.10.4
PREFIX=/usr/lib/ghc-6.10.4
DST="${OUTPUT_DIR}${PREFIX}"
BOOTDIR=/usr/lib/ghc-6.6.1/bin
BUILDROOT=$PWD
BIN=$BUILDROOT/bin
TREE=$BUILDROOT/ghc-$V
export HOME=$BUILDROOT/home; mkdir -p $HOME   # ghc-pkg reads $HOME

# --- C toolchain: the bedrock gcc against the versioned glibc sysroot (as every rung of the GHC ladder) ---
SR=/usr/lib/glibc-bedrock-2.42; LOADER=$SR/lib/ld-linux-x86-64.so.2
[ -e $SR/lib/libc.so ] && [ -e $LOADER ] || { echo "ghc-6.10.4: glibc sysroot missing at $SR" >&2; exit 1; }
mkdir -p $BIN/fixlib
# the sysroot's libc.so is a linker script with staging paths; regenerate it
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@$SR/lib/\1@g" $SR/lib/libc.so > $BIN/fixlib/libc.so
grep -q '/build/output' $BIN/fixlib/libc.so && { echo "ghc-6.10.4: libc.so fixup failed" >&2; exit 1; }
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
export PATH=$BIN:$PATH
# --- P0 ---
[ -x $BOOTDIR/ghc ] && [ -x $BOOTDIR/ghc-pkg ] || { echo "ghc-6.10.4: no boot compiler at $BOOTDIR (ghc-6.6.1)" >&2; exit 1; }
$BOOTDIR/ghc --version 2>&1 | grep -q 'version 6.6.1' || { echo "ghc-6.10.4: boot compiler is not 6.6.1" >&2; exit 1; }
[ -f ghc-$V-src.tar.bz2 ] || { echo "ghc-6.10.4: source absent" >&2; exit 1; }
[ -f /usr/include/curses.h ] || { echo "ghc-6.10.4: curses.h missing (terminfo)" >&2; exit 1; }
[ -f /usr/include/gmp.h ] || { echo "ghc-6.10.4: gmp.h missing" >&2; exit 1; }

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

# --- P2 configure + build ---
mkdir -p $TREE; tar xjf ghc-$V-src.tar.bz2 -C $TREE --strip-components=1 --no-same-owner
cd $TREE
# configure takes the ghc-pkg beside the ghc it is given
CC=gcc89 ./configure --with-ghc=$BOOTDIR/ghc --with-gcc=gcc89 > configure.log 2>&1 || { tail -20 configure.log >&2; echo "ghc-6.10.4: configure failed" >&2; exit 1; }
grep -a 'checking for ghc-pkg' configure.log | grep -q "$BOOTDIR" || { echo "ghc-6.10.4: configure did not take the boot ghc-pkg" >&2; exit 1; }
grep -q 'x86_64-unknown-linux' mk/config.mk || { echo "ghc-6.10.4: platform is not x86_64-unknown-linux" >&2; exit 1; }
cat > mk/build.mk <<'EOF'
# unregisterised: rts/Makefile forces -fvia-C for every .cmm (the NCG cannot do Cmm loops), and registerised via-C
# needs the evil mangler, which neither a modern perl nor a modern gcc's assembly survives
GhcUnregisterised    = YES
GhcWithNativeCodeGen = NO
GhcWithInterpreter   = NO
SplitObjs            = NO
GhcLibWays           =
GhcBootLibs          = YES
# no threaded/debug RTS ways: THREADED_RTS needs BaseReg in a register, which an unregisterised build has not
GhcRTSWays           =
GhcNotThreaded       = YES
# stage 1 is compiled by 6.6.1 (big stack/heap for its RTS; the string-gap-safe cpp)
GhcHcOpts           += +RTS -K512m -M8g -RTS -pgmP cpp-gap
# libraries and stage 2 are compiled by stage 1, whose cpp mangles string gaps the same way
GhcLibHcOpts        += +RTS -K512m -RTS -pgmP cpp-gap
GhcStage2HcOpts     += +RTS -K512m -RTS -pgmP cpp-gap
EOF
make > all.log 2>&1 || { grep -aiE 'error:|\*\*\*|panic|Segmentation|not in scope|parse error' all.log | grep -v warning | head -12 >&2; echo "ghc-6.10.4: make failed" >&2; exit 1; }
G=$TREE/ghc/stage2-inplace/ghc   # 6.10 moved the in-place compiler out of compiler/
$G --version 2>&1 | grep -q "version $V" || { echo "ghc-6.10.4: stage 2 compiler does not report $V" >&2; exit 1; }

# --- P3 gate: programs through stage 2 against recorded outputs ---
T=$BUILDROOT/test; mkdir -p $T; cd $T
printf 'main = putStrLn "hello from ghc 6.10.4"\n' > hello.hs; echo 'hello from ghc 6.10.4' > hello.expected
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
for p in hello num; do
  $G -O -o $p $p.hs > $p.log 2>&1 || { tail -15 $p.log >&2; echo "ghc-6.10.4: stage 2 could not compile $p.hs" >&2; exit 1; }
  ./$p +RTS -K256m -RTS > $p.out 2>&1
  cmp -s $p.out $p.expected || { diff $p.expected $p.out | head -8 >&2; echo "ghc-6.10.4: $p output differs" >&2; exit 1; }
done

# --- P4 install: stage 2's tree, less objects and intermediates, with its absolute paths pointed at the prefix ---
cd $BUILDROOT
mkdir -p "$DST/bin"
# the C compiler wrappers the installed compiler runs, with the regenerated libc.so beside them
install -m 0755 $BIN/gcc $BIN/gcc89 $BIN/cpp-gap "$DST/bin/"; ln -sf gcc "$DST/bin/cc"
mkdir -p "$DST/lib"; cp -a $BIN/fixlib "$DST/lib/fixlib"; sed -i "s|$BIN/fixlib|$PREFIX/lib/fixlib|" "$DST/bin/gcc"
cp -a $TREE "$DST/ghc-$V"
find "$DST/ghc-$V" \( -name '*.o' -o -name '*.hc' -o -name '*.log' -o -name '*_stub.c' \) -type f -delete
find "$DST/ghc-$V" \( -name config.status -o -name config.log -o -name config.cache \) -type f -delete   # configure's records
grep -rlI "$BUILDROOT" "$DST/ghc-$V" | xargs -r sed -i "s|$TREE|$PREFIX/ghc-$V|g; s|$BUILDROOT/bin|$PREFIX/bin|g; s|$BUILDROOT/home|/tmp|g"
grep -rlI "$BUILDROOT" "$DST/ghc-$V" | head -3 | grep -q . && { echo "ghc-6.10.4: build-root paths remain in the installed tree" >&2; exit 1; } || true
cat > "$DST/bin/ghc" <<EOF
#!/bin/sh
PATH=$PREFIX/bin:\$PATH; export PATH
exec $PREFIX/ghc-$V/ghc/stage2-inplace/ghc "\$@"
EOF
cat > "$DST/bin/ghc-pkg" <<EOF
#!/bin/sh
exec $PREFIX/ghc-$V/utils/ghc-pkg/install-inplace/bin/ghc-pkg --global-conf=$PREFIX/ghc-$V/inplace-datadir/package.conf "\$@"
EOF
chmod 0755 "$DST/bin/ghc" "$DST/bin/ghc-pkg"
echo "ghc-6.10.4: installed $(du -sh "$DST" | cut -f1) at $PREFIX"
