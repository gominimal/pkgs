#!/bin/bash
# ghc-5.04.3 booted by ghc-4.08.2: stage 1 (compiled by 4.08.2) builds the libraries and a stage 2 of itself; stage 2's
# tree is what gets installed. Phases: P0 preconditions, P1 wrappers, P2 stage 1, P3 stage 2, P4 gate, P5 install.
set -euo pipefail
trap 'echo "ghc-5.04.3: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
V=5.04.3
PREFIX=/usr/lib/ghc-5.04.3
DST="${OUTPUT_DIR}${PREFIX}"
BOOT=/usr/lib/ghc-4.08.2/bin/ghc-4.08.2
BUILDROOT=$PWD
BIN=$BUILDROOT/bin
SERIES="configure-x86_64 mblock-64bit cast-lvalue rts-carry driver-x86_64 gcc15-c boot408-hschooks boot408-happy64 gcc15-rts-net glibc-modern boot408-floatlit uniqfm-64bit"

# --- C toolchain: the bedrock gcc against the versioned glibc sysroot (as every rung of the GHC ladder) ---
SR=/usr/lib/glibc-bedrock-2.42; LOADER=$SR/lib/ld-linux-x86-64.so.2
[ -e $SR/lib/libc.so ] && [ -e $LOADER ] || { echo "ghc-5.04.3: glibc sysroot missing at $SR" >&2; exit 1; }
mkdir -p $BIN/fixlib
# the sysroot's libc.so is a linker script with staging paths; regenerate it
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@$SR/lib/\1@g" $SR/lib/libc.so > $BIN/fixlib/libc.so
grep -q '/build/output' $BIN/fixlib/libc.so && { echo "ghc-5.04.3: libc.so fixup failed" >&2; exit 1; }
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
[ -x $BOOT ] || { echo "ghc-5.04.3: no boot compiler at $BOOT (ghc-4.08.2)" >&2; exit 1; }
[ -f ghc-$V-src.tar.bz2 ] || { echo "ghc-5.04.3: source tarball absent" >&2; exit 1; }
for p in $SERIES; do [ -f $p.patch ] || { echo "ghc-5.04.3: $p.patch absent" >&2; exit 1; }; done
[ -f /usr/include/gmp.h ] || { echo "ghc-5.04.3: gmp.h missing" >&2; exit 1; }

# --- P1 wrappers, found through PATH (configure's --with-gcc is baked into the compiler by name, so they ship in P5) ---
mkdir -p $BIN
# one gcc for configure, the makefiles and the compiler's C backend: 2002-era C, non-PIE
cat > $BIN/gcc89 <<'EOF'
#!/bin/sh
exec gcc -std=gnu89 -fcommon -fno-strict-aliasing -Wno-implicit-int -Wno-implicit-function-declaration \
  -Wno-int-conversion -Wno-incompatible-pointer-types -no-pie "$@"
EOF
# the compiler's cpp (-pgmP): gcc -E splices backslash(+blanks)-newline even with -traditional, destroying Haskell string
# gaps and operators such as `infix 5 \\` at a line end. Protect every line-final backslash on non-directive lines (a \002
# marker, stripped afterwards); the temporary copy sits beside the input so relative #includes resolve; line markers
# point back at the real file.
cat > $BIN/cpp-gap <<'EOF'
#!/bin/bash
args=("$@"); out=; in_i=-1
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = "-o" ] && out=${args[$((i + 1))]}
  [ "${args[$i]}" = "-x" ] && [ "${args[$((i + 1))]:-}" = "c" ] && in_i=$((i + 2))
done
[ $in_i -ge 0 ] || exec gcc89 -E -undef -traditional "$@"
in=${args[$in_i]}; tmp=$(mktemp "$(dirname "$in")/.cppgap.XXXXXX")
perl -e '$d = 0; while (<>) { $d = 1 if /^\s*#/; if ($d) { $d = /\\[ \t]*\r?\n$/ ? 1 : 0 } else { s/\\([ \t]*\r?\n)$/\\\002$1/ } print }' "$in" > "$tmp"
args[$in_i]=$tmp
gcc89 -E -undef -traditional "${args[@]}"; rc=$?
[ -n "$out" ] && [ -f "$out" ] && T="$tmp" I="$in" perl -pi -e 's/\002//g; s/\Q$ENV{T}\E/$ENV{I}/g' "$out"
rm -f "$tmp"; exit $rc
EOF
chmod 0755 $BIN/gcc89 $BIN/cpp-gap
# configure looks for ghc-pkg beside the ghc it is given; the boot has none (4.08 has no packages database)
mkdir -p $BUILDROOT/boot; ln -sf $BOOT $BUILDROOT/boot/ghc

unpack_patch() { # $1 = tree dir
  mkdir -p "$1"; tar xjf ghc-$V-src.tar.bz2 -C "$1" --strip-components=1 --no-same-owner
  for p in $SERIES; do ( cd "$1" && patch -p1 --forward --no-backup-if-mismatch < "$BUILDROOT/$p.patch" > /dev/null ); done
}
BUILDMK='GhcUnregisterised    = YES
GhcWithInterpreter   = NO
GhcWithNativeCodeGen = NO
SplitObjs            = NO
GhcLibsWithReadline  = NO
GhcLibsWithObjectIO  = NO
GhcLibsWithHOpenGL   = NO
GhcRtsWithFrontPanel = NO
GhcLibWays           =
'
faildir() { awk '/Entering directory/{d=$NF} /\*\*\* \[|Error [0-9]/{print d; exit}' "$1" | tr -d "'\`"; }

# --- P2 stage 1: 4.08.2 compiles the compiler (no -O: 4.08's optimiser on 5.04's sources is slow and fragile) ---
S1=$BUILDROOT/s1
unpack_patch $S1
( cd $S1 && CC=gcc89 ./configure --with-ghc=$BUILDROOT/boot/ghc --with-gcc=gcc89 > configure.log 2>&1 ) || { tail -20 $S1/configure.log >&2; echo "ghc-5.04.3: stage 1 configure failed" >&2; exit 1; }
grep -q 'x86_64-unknown-linux' $S1/mk/config.mk || { echo "ghc-5.04.3: stage 1 platform is not x86_64-unknown-linux" >&2; exit 1; }
# stage 1 runs on 4.08's RTS (1 MB default stack); the library makefiles race under -j
{ printf '%s' "$BUILDMK"; echo 'FptoolsHcOpts        ='; echo 'GhcLibHcOpts         += +RTS -K512m -M8g -RTS -pgmP cpp-gap'; } > $S1/mk/build.mk
( cd $S1 && make boot > boot.log 2>&1 ) || { grep -aiE 'error|\*\*\*' $S1/boot.log | head -8 >&2; echo "ghc-5.04.3: stage 1 make boot failed in $(faildir $S1/boot.log)" >&2; exit 1; }
( cd $S1 && make all > all.log 2>&1 ) || { grep -aiE '^[^ ]*: error|error:|\*\*\*|panic|Segmentation' $S1/all.log | head -10 >&2; echo "ghc-5.04.3: stage 1 make all failed in $(faildir $S1/all.log)" >&2; exit 1; }
G1=$S1/ghc/compiler/ghc-inplace
$G1 --version 2>&1 | grep -q "version $V" || { echo "ghc-5.04.3: stage 1 compiler does not report $V" >&2; exit 1; }

# --- P3 stage 2: the same tree again, compiled by stage 1 ---
S2=$BUILDROOT/ghc-$V
unpack_patch $S2
mkdir -p $BUILDROOT/boot1; ln -sf $G1 $BUILDROOT/boot1/ghc; ln -sf $S1/ghc/utils/ghc-pkg/ghc-pkg-inplace $BUILDROOT/boot1/ghc-pkg
( cd $S2 && CC=gcc89 ./configure --with-ghc=$BUILDROOT/boot1/ghc --with-gcc=gcc89 > configure.log 2>&1 ) || { tail -20 $S2/configure.log >&2; echo "ghc-5.04.3: stage 2 configure failed" >&2; exit 1; }
# both the boot (stage 1) and the new compiler run on 5.04's RTS
{ printf '%s' "$BUILDMK"; echo 'SRC_HC_OPTS          += +RTS -K512m -M8g -RTS -pgmP cpp-gap'; } > $S2/mk/build.mk
( cd $S2 && make all > all.log 2>&1 ) || { grep -aiE 'error:|\*\*\*|panic|Segmentation|not in scope|parse error' $S2/all.log | head -10 >&2; echo "ghc-5.04.3: stage 2 make all failed in $(faildir $S2/all.log)" >&2; exit 1; }
G2=$S2/ghc/compiler/ghc-inplace
$G2 --version 2>&1 | grep -q "version $V" || { echo "ghc-5.04.3: stage 2 compiler does not report $V" >&2; exit 1; }

# --- P4 gate: programs through stage 2 against recorded outputs, and stage 1 == stage 2 on the same source's C ---
T=$BUILDROOT/test; mkdir -p $T; cd $T
printf 'main = putStrLn "hello from ghc 5.04.3"\n' > hello.hs
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
echo 'hello from ghc 5.04.3' > hello.expected
for p in hello num; do
  $G2 -o $p $p.hs > $p.log 2>&1 || { tail -15 $p.log >&2; echo "ghc-5.04.3: stage 2 could not compile $p.hs" >&2; exit 1; }
  ./$p +RTS -K256m -RTS > $p.out 2>&1   # 5.04 programs default to a 1 MB stack
  cmp -s $p.out $p.expected || { diff $p.expected $p.out | head -8 >&2; echo "ghc-5.04.3: $p output differs" >&2; exit 1; }
done
for g in 1 2; do gi=$G1; [ $g = 2 ] && gi=$G2; mkdir -p hc$g && ( cd hc$g && $gi -C -O -o num.hc ../num.hs > log 2>&1 ); done
cmp -s hc1/num.hc hc2/num.hc || { echo "ghc-5.04.3: stage 1 and stage 2 emit different C for num.hs" >&2; exit 1; }

# --- P5 install: stage 2's tree, less objects and intermediates, with its absolute paths pointed at the prefix ---
cd $BUILDROOT
mkdir -p "$DST/bin"
# the C compiler wrappers the installed compiler runs, with the regenerated libc.so beside them
install -m 0755 $BIN/gcc $BIN/gcc89 $BIN/cpp-gap "$DST/bin/"; ln -sf gcc "$DST/bin/cc"
mkdir -p "$DST/lib"; cp -a $BIN/fixlib "$DST/lib/fixlib"; sed -i "s|$BIN/fixlib|$PREFIX/lib/fixlib|" "$DST/bin/gcc"
cp -a $S2 "$DST/ghc-$V"
find "$DST/ghc-$V" \( -name '*.o' -o -name '*.hc' -o -name '*.log' -o -name '*.hi-boot' -o -name '*_stub.c' \) -type f -delete
find "$DST/ghc-$V" -name '*.hi-boot' -delete 2>/dev/null || true
# in-place scripts, package.conf.inplace and the makefiles' recorded top: text files carrying the build root
grep -rlI "$BUILDROOT" "$DST/ghc-$V" | xargs -r sed -i "s|$S2|$PREFIX/ghc-$V|g; s|$BUILDROOT/bin|$PREFIX/bin|g"
grep -rlI "$BUILDROOT" "$DST/ghc-$V" | head -3 | grep -q . && { echo "ghc-5.04.3: build-root paths remain in the installed tree" >&2; exit 1; } || true
# the next rung's boot: configure reads --version; the in-place scripts carry -B
cat > "$DST/bin/ghc" <<EOF
#!/bin/sh
PATH=$PREFIX/bin:\$PATH; export PATH
exec $PREFIX/ghc-$V/ghc/compiler/ghc-inplace "\$@"
EOF
cat > "$DST/bin/ghc-pkg" <<EOF
#!/bin/sh
exec $PREFIX/ghc-$V/ghc/utils/ghc-pkg/ghc-pkg-inplace "\$@"
EOF
chmod 0755 "$DST/bin/ghc" "$DST/bin/ghc-pkg"
echo "ghc-5.04.3: installed $(du -sh "$DST" | cut -f1) at $PREFIX"
