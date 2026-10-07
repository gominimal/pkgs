#!/bin/bash
# ghc-4.08.2: the first GHC of the source-only ladder (microhs-0.16 -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 -> 7.0.4 ->
# 7.6.3 -> ...). No GHC binary is an input: GHC 4.08.2's own compiler (hsc) is compiled by MicroHs from a desugared copy
# of its sources, that MicroHs-hosted hsc compiles the Prelude, the lang library and then the compiler itself to C, and
# gcc links the result into a native hsc. The in-place tree (driver, utilities, libraries, hslibs) is installed whole at
# /usr/lib/ghc-4.08.2/w with its paths rewritten; the next rung drives it through ghc/driver/ghc-unreg.
# phases: P0 preconditions, P1 layout, P2 patches, P3 configure, P4 tools, P5 happy + parsers, P6 hsc on MicroHs,
# P7 libraries, P8 C side, P9 the compiler compiled by itself (gen1), P10 native hsc, P11 gate, P12 in-place tree +
# hslibs, P13 install.
set -euo pipefail
trap 'echo "ghc-4.08.2: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
VERSION=4.08.2
PREFIX=/usr/lib/ghc-4.08.2
DST="${OUTPUT_DIR}${PREFIX}"
MHS=/usr/lib/microhs-0.16/bin
J=$(nproc)
# 2000-era C on a modern gcc: gnu89, tentative definitions as commons, warnings stay warnings, and `char` signed as on
# the x86 the code was written for (unlit emits nothing with aarch64's unsigned char)
CCP="gcc -std=gnu89 -fcommon -fsigned-char -Wno-implicit-int -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
BUILDROOT=$PWD
W=$BUILDROOT/w   # the lab tree's /w; every script below is rewritten to this path
BIN=$BUILDROOT/bin

# --- C toolchain. x86_64: the bedrock gcc against the versioned glibc sysroot (as every rung of the GHC ladder);
# aarch64: the toolchain gcc, itself built from the hex0 seed, as is
if [ "$(uname -m)" = x86_64 ]; then
  SR=/usr/lib/glibc-bedrock-2.42; LOADER=$SR/lib/ld-linux-x86-64.so.2
  [ -e $SR/lib/libc.so ] && [ -e $LOADER ] || { echo "ghc-4.08.2: glibc sysroot missing at $SR" >&2; exit 1; }
  mkdir -p $BIN/fixlib
  # the sysroot's libc.so is a linker script with staging paths; regenerate it
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@$SR/lib/\1@g" $SR/lib/libc.so > $BIN/fixlib/libc.so
  grep -q '/build/output' $BIN/fixlib/libc.so && { echo "ghc-4.08.2: libc.so fixup failed" >&2; exit 1; }
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
for x in $MHS/mhs $MHS/cpphs; do [ -x "$x" ] || { echo "ghc-4.08.2: missing $x (microhs-0.16)" >&2; exit 1; }; done
for f in ghc-4.08.2-src.tar.bz2 happy-1.16.tar.gz ghc-4.08.2-microhs-overlay.tar.gz gnu-config-config.guess gnu-config-config.sub; do
  [ -f "$f" ] || { echo "ghc-4.08.2: source $f absent" >&2; exit 1; }
done
[ -f /usr/include/gmp.h ] || { echo "ghc-4.08.2: gmp.h missing" >&2; exit 1; }

# --- P1 layout ---
mkdir -p "$W"
tar xzf ghc-4.08.2-microhs-overlay.tar.gz -C "$W" --no-same-owner     # D S patches tests scripts happy-1.16/{mhs,gen,regen} T/lib/PrelGHC.hi*
tar xjf ghc-4.08.2-src.tar.bz2 -C "$W" --no-same-owner                 # ghc-4.08.2/
tar xzf happy-1.16.tar.gz -C "$W" --no-same-owner                      # happy-1.16/ (the overlay dirs inside it survive)
# the scripts were written for a tree at /w and a MicroHs at /w/MicroHs-0.16.0.0
perl -pi -e "s#/w/MicroHs-0.16.0.0/bin#$MHS#g; s#/w\\b#$W#g" "$W"/*.sh "$W"/*.py
grep -rlP '(?<![\w.~-])/w\b' "$W"/*.sh "$W"/*.py && { echo "ghc-4.08.2: a /w path survived the rewrite" >&2; exit 1; } || true   # $W itself ends in /w
chmod +x "$W"/*.sh

# --- P2 patches: 64-bit and modern-toolchain fixes to the 2001 tree (each patch names its site) ---
cd "$W/ghc-4.08.2"
for p in "$W"/patches/ghc_*.patch "$W"/patches/hslibs_*.patch "$W"/patches/configure.patch; do patch -p1 --no-backup-if-mismatch < "$p"; done
# the bundled config.guess/config.sub predate x86_64
for d in . ghc/rts/gmp; do cp "$BUILDROOT/gnu-config-config.guess" $d/config.guess; cp "$BUILDROOT/gnu-config-config.sub" $d/config.sub; chmod +x $d/config.guess $d/config.sub; done

# --- P3 configure: the platform case the configure patch adds; happy is a stand-in (the real one comes from P5) ---
mkdir -p "$W/fakebin"; printf '#!/bin/sh\necho "Happy Version 1.9 Copyright (c) fake"\n' > "$W/fakebin/happy"; chmod +x "$W/fakebin/happy"
TR=x86_64-unknown-linux-gnu
PATH="$W/fakebin:$PATH" CC="$CCP" ./configure --build=$TR --host=$TR --target=$TR > "$W/configure.log" 2>&1 \
  || { tail -20 "$W/configure.log" >&2; echo "ghc-4.08.2: configure failed" >&2; exit 1; }
# configure writes mk/config.h; the includes Makefile prepends the platform defines and copies it down. Not gmp.h: the
# bundled GMP 2 header (mpz_cmp_si, __mpn_*) would shadow the system one the RTS links against
make -C ghc/includes config.h > "$W/includes.log" 2>&1 || { tail -10 "$W/includes.log" >&2; echo "ghc-4.08.2: ghc/includes/config.h did not build" >&2; exit 1; }
rm -f ghc/includes/gmp.h
grep -q 'SIZEOF_VOID_P 8' ghc/includes/config.h || { echo "ghc-4.08.2: config.h is not 64-bit" >&2; exit 1; }
grep -q 'x86_64_unknown_linux_HOST' ghc/includes/config.h || { echo "ghc-4.08.2: config.h lacks the platform defines" >&2; exit 1; }

# --- P4 tools: unlit (literate Haskell -> Haskell), used by every library build below ---
$CCP -include string.h -include stdlib.h -o "$W/unlit" ghc/utils/unlit/unlit.c

# --- P5 happy 1.16 compiled by MicroHs, then GHC's two parsers ---
# happy's modules carry #if blocks (cpphs runs on them); mhs/ holds the two modules MicroHs needs replaced (a modern
# ParseMonad, a GLR stub), gen/ the Paths module, regen/ a seed for the parser generator's own two generated parsers
# (from an unrelated happy). The seed's happy regenerates them; the happy built from THAT output regenerates it byte
# for byte: the fixed point is what compiles GHC's parsers.
H="$W/happy-1.16"
build_happy() { # $1 build dir, $2 dir holding Parser.hs + AttrGrammarParser.hs
  mkdir -p "$1"; cp "$H"/src/*.lhs "$H"/src/*.hs "$H"/mhs/* "$H"/gen/* "$1"/; cp "$2"/Parser.hs "$2"/AttrGrammarParser.hs "$1"/
  sed -i "s|/w/happy-1.16/templates|$H/templates|" "$1/Paths_happy.hs"
  ( cd "$1" && MHSCPPHS=$MHS/cpphs $MHS/mhs -XCPP -i"$1" -i"$W/S" Main -o "$1/happy" > mhs.log 2>&1 ) || { grep -v '^loaded' "$1/mhs.log" | tail -5 >&2; echo "ghc-4.08.2: happy did not build in $1" >&2; exit 1; }
}
regen_happy_parsers() { # $1 happy binary, $2 out dir
  mkdir -p "$2" && ( cd "$2" && "$1" -t "$H/templates" "$H/src/Parser.ly" -o Parser.hs && "$1" -t "$H/templates" "$H/src/AttrGrammarParser.ly" -o AttrGrammarParser.hs )
}
cpp -P -traditional -undef "$H/templates/GenericTemplate.hs" > "$H/templates/HappyTemplate"
cpp -P -traditional -undef -DHAPPY_ARRAY "$H/templates/GenericTemplate.hs" > "$H/templates/HappyTemplate-arrays"
build_happy "$W/happyB" "$H/regen";  regen_happy_parsers "$W/happyB/happy" "$W/outB"
build_happy "$W/happyC" "$W/outB";   regen_happy_parsers "$W/happyC/happy" "$W/outC"
cmp -s "$W/outC/Parser.hs" "$W/outB/Parser.hs" && cmp -s "$W/outC/AttrGrammarParser.hs" "$W/outB/AttrGrammarParser.hs" || { echo "ghc-4.08.2: happy is not a fixed point of its own parsers" >&2; exit 1; }
HAPPY="$W/happyC/happy"
mkdir -p "$W/T/ghcparse"
"$HAPPY" -t "$H/templates" ghc/compiler/parser/Parser.y -o "$W/T/ghcparse/Parser.hs"
"$HAPPY" -t "$H/templates" ghc/compiler/rename/ParseIface.y -o "$W/T/ghcparse/ParseIface.hs"
python3 "$W/happyfix.py" "$W/T/ghcparse/Parser.hs" "$W/T/ghcparse/ParseIface.hs"   # the 4.08-era compiler cannot type happy 1.16's output as emitted

# --- P6 hsc on MicroHs: the compiler proper, from the desugared module set D/ with the S/ shims ---
mkdir -p "$W/T"
$MHS/mhs -i"$W/D" -i"$W/S" Main -o "$W/T/hsc408" > "$W/hsc408-build.log" 2>&1 || { grep -v '^loaded' "$W/hsc408-build.log" | tail -8 >&2; echo "ghc-4.08.2: hsc did not build on MicroHs" >&2; exit 1; }
[ -x "$W/T/hsc408" ] && [ "$(stat -c%s "$W/T/hsc408")" -gt 1000000 ] || { echo "ghc-4.08.2: hsc408 missing or truncated" >&2; exit 1; }   # it is exercised by P7

# --- P7 libraries: std (the Prelude) and hslibs/lang, compiled to C by the MicroHs-hosted hsc ---
mkdir -p "$W/T/lib" "$W/T/lang"
cp -n ghc/lib/std/*.hi-boot "$W/T/lib/"   # the mutually recursive Prelude modules import through these; the overlay's PrelGHC pair stays
# The happy parsers and Lex collect garbage constantly in MicroHs's default 50M-cell heap; 600M cells (~9.6 GB each)
# gives byte-identical .hc about 3x faster.
cat > "$W/T/hsc408-heap" <<EOF
#!/bin/sh
case " \$* " in *" Parser.hs "*|*" ParseIface.hs "*|*" Lex.hs "*) exec "$W/T/hsc408" +RTS -H600000000 -RTS "\$@" ;; esac
exec "$W/T/hsc408" "\$@"
EOF
chmod +x "$W/T/hsc408-heap"
# The overlay's libbuild.sh/langbuild.sh compile one module at a time in retry rounds. Their preprocessing runs as is;
# their per-module compile (libone.sh, the same commands) runs in import order, DJ at a time (dagbuild.py).
DJ=$(( J > 2 ? J - 2 : 1 ))
sed '/^todo=/,$d' "$W/libbuild.sh" > "$W/libprep.sh"; sed '/^todo=/,$d' "$W/langbuild.sh" > "$W/langprep.sh"
cat > "$W/libone.sh" <<'EOF'
#!/bin/bash
# libone.sh SRCDIR PKG HIMAP MOD: one module as libbuild.sh/langbuild.sh compile it; prints OK/WAIT/FAIL like compone.sh
set -f; L=$1; pkg=$2; himap=$3; m=$4
opts=$(grep -ohE -- '-fno-implicit-prelude|-fglasgow-exts' $L/$m.lhs $L/$m.hs 2>/dev/null | sort -u | tr '\n' ' ')
"$HSC" $m.hs -fglasgow-exts $opts -static -funregisterised -inpackage=$pkg -fhi-version=408 -fsimplify "[" -fmax-simplifier-iterations4 "]" "-himap=$himap" -olang=C -ofile=$m.hc -hifile=$m.hi-raw > $m.log 2>&1
[ -s $m.hi-raw ] && python3 "$POSTIFACE" $m.hi-raw $m.hi 2>>$m.log
if [ -s $m.hc ] && [ -s $m.hi ] && ! grep -q "Compilation had errors" $m.log; then echo "OK   $m ($(wc -c < $m.hc) B)"
elif grep -qE "Could not find interface file|Bad interface file" $m.log; then echo "WAIT $m"; rm -f $m.hc $m.hi $m.hi-raw
else echo "FAIL $m: $(grep -vE 'topCoreBindsToStg|^    <THIS>|^      =|ifaceBinds|Warning|^$' $m.log | head -3 | tr '\n' ' ' | cut -c1-200)"; rm -f $m.hc $m.hi $m.hi-raw; fi
EOF
export HSC="$W/T/hsc408-heap" POSTIFACE="$W/postiface.py"
libdag() { # dir srcdir pkg himap mods expected
  ( cd "$1" && bash "$W/$(basename "$1")prep.sh" )
  MODS="$5" python3 "$BUILDROOT/dagbuild.py" "$1" $DJ bash "$W/libone.sh" "$2" "$3" "$4" > "$1/dagbuild.log" 2>&1 || true
  n=$(find "$1" -maxdepth 1 -name '*.hc' -size +0 | wc -l)
  [ "$n" -eq "$6" ] || { grep -E 'never compiled|FAIL' "$1/dagbuild.log" | tail -5 >&2; echo "ghc-4.08.2: $3 library incomplete ($n/$6)" >&2; exit 1; }
}
L=ghc/lib/std; libdag "$W/T/lib" "$W/ghc-4.08.2/$L" std "$W/T/lib%.hi" "$(ls $L/*.lhs | xargs -n1 basename | sed 's/\.lhs$//' | grep -vE '^(PrelHugs|PrelMain|Main)$')" 43
L=hslibs/lang; libdag "$W/T/lang" "$W/ghc-4.08.2/$L" lang "$W/T/lang%.hi:$W/T/lib%.hi" "$(ls $L/*.lhs $L/*.hs | xargs -n1 basename | sed -E 's/\.l?hs$//')" 31

# --- P8 the C side: RTS, hooks, cbits, the libraries' .hc ---
bash "$W/cbuild.sh" > "$W/cbuild.log" 2>&1; grep -q 'CBUILD_DONE.*bad=0' "$W/cbuild.log" || { grep '^BAD' "$W/cbuild.log" | head -5 >&2; echo "ghc-4.08.2: C side failed" >&2; exit 1; }

# --- P9 gen1: the compiler's own sources (cpp'd here, parsers from P5) compiled by the MicroHs-hosted hsc ---
mkdir -p "$W/T/comp"
( cd "$W/T/comp" && PREP_ONLY=1 bash "$W/compbuild.sh" )
# compbuild.sh's compile step (compone.sh per module) in import order, DJ at a time, Parser and ParseIface overlapping
( cd "$W/T/comp" && find . -maxdepth 1 \( -name '*.hc' -o -name '*.hi' -o -name '*.hi-raw' \) -delete )
OUT="$W/T/comp" python3 "$BUILDROOT/dagbuild.py" "$W/T/comp" $DJ bash "$W/compone.sh" > "$W/T/comp/compbuild.log" 2>&1 || true
nhs=$(ls "$W"/T/comp/*.hs | grep -vc unlit); nhc=$(find "$W/T/comp" -maxdepth 1 -name '*.hc' -size +0 | wc -l)
[ "$nhc" -ge "$nhs" ] || { grep -E 'never compiled|FAIL' "$W/T/comp/compbuild.log" | tail -5 >&2; echo "ghc-4.08.2: gen1 incomplete ($nhc/$nhs modules)" >&2; exit 1; }

# --- P10 the native hsc ---
( cd "$W/T/comp" && bash "$W/link-hsc.sh" > "$W/link-hsc.log" 2>&1 )
[ -x "$W/T/comp/hsc-native" ] || { tail -15 "$W/link-hsc.log" >&2; echo "ghc-4.08.2: native hsc did not link" >&2; exit 1; }

# --- P11 gate: the 27 differential tests against recorded reference outputs (a modern GHC's, t25's the 4.08-era one) ---
CF="-x c -c -O0 -w -include stdlib.h -std=gnu89 -fno-strict-aliasing -Wno-implicit-function-declaration -D_GNU_SOURCE -DUSE_MINIINTERPRETER -DNO_REGS -Dlinux_TARGET_OS=1 -Dx86_64_TARGET_ARCH=1 -D__encodeFloat=__encodeDouble -D__int_encodeFloat=__int_encodeDouble -I$W/ghc-4.08.2/ghc/includes -include Stg.h"
HSC="$W/T/comp/hsc-native +RTS -K512m -M8g -RTS"
pass=0; fail=0
for t in "$W"/tests/t*.hs; do n=$(basename "${t%.hs}"); d="$W/tests/run/$n"; mkdir -p "$d"; cp "$t" "$d/Main.hs"; cp "$W/T/lib/PrelMain.hs" "$d/"
  if ( cd "$d" && $HSC Main.hs -fglasgow-exts -static -funregisterised -fhi-version=408 -fsimplify "[" -fmax-simplifier-iterations4 "]" "-himap=$W/T/lib%.hi" -olang=C -ofile=Main.hc -hifile=Main.hi-raw > hsc.log 2>&1 \
       && python3 "$W/postiface.py" Main.hi-raw Main.hi \
       && $HSC PrelMain.hs -fglasgow-exts -static -funregisterised -inpackage=std -fhi-version=408 -fsimplify "[" -fmax-simplifier-iterations4 "]" "-himap=$W/T/lib%.hi:$d%.hi" -olang=C -ofile=PrelMain.hc -hifile=PrelMain.hi > pm.log 2>&1 \
       && gcc $CF Main.hc -o Main.o && gcc $CF PrelMain.hc -o PrelMain.o \
       && gcc -no-pie -o prog Main.o PrelMain.o $(ls "$W"/T/lib/obj/*.o | grep -v /PrelMain.o) "$W"/T/rts/*.o "$W"/T/cbits/*.o "$W"/T/hooks/*.o "$W"/T/inl/*.o -lgmp -lm > link.log 2>&1 ) \
     && ( cd "$d" && timeout 120 ./prog +RTS -K512m -M2g -RTS > out 2> err; echo $? > rc ) \
     && cmp -s "$d/out" "$W/tests/expected/$n.out" && cmp -s "$d/rc" "$W/tests/expected/$n.rc"; then pass=$((pass+1)); else fail=$((fail+1)); echo "ghc-4.08.2: test $n differs from its reference" >&2; fi
done
echo "ghc-4.08.2: differential tests pass=$pass fail=$fail"
[ "$fail" = 0 ] && [ "$pass" = 27 ] || { echo "ghc-4.08.2: gate failed" >&2; exit 1; }

# --- P12 the in-place tree: driver + utilities + archives, the native hsc behind the compiler wrapper, then hslibs ---
bash "$W/inplace.sh" > "$W/inplace.log" 2>&1 || { tail -10 "$W/inplace.log" >&2; echo "ghc-4.08.2: in-place assembly failed" >&2; exit 1; }
# the wrapper's default implementation becomes the native compiler, under GHC's own RTS
sed -i "s|impl=\${HSC_IMPL:-$W/T/hsc408}|impl=\${HSC_IMPL:-$W/T/comp/hsc-native}; export HSC_NATIVE=\${HSC_NATIVE:-1}|" ghc/compiler/hsc
grep -q 'hsc-native' ghc/compiler/hsc || { echo "ghc-4.08.2: hsc wrapper rewrite did not apply" >&2; exit 1; }
G=ghc/driver/ghc-unreg; chmod +x "$G"   # the driver variant comes in by patch, which sets no mode bits
cp "$W"/T/lang/*.hi hslibs/lang/ && ar rcs hslibs/lang/libHSlang.a "$W"/T/lang/obj/*.o
( cd hslibs/lang/cbits && $CCP -O -I../../../ghc/includes -c PackedString.c -o PackedString.o && ar rcs libHSlang_cbits.a PackedString.o )
printf 'main = print (maxBound :: Int, minBound :: Int)\n' > "$W/mb.hs"; "$G" -o "$W/mb" "$W/mb.hs" > "$W/mb.log" 2>&1 && [ "$("$W/mb" +RTS -K64m -RTS)" = "(9223372036854775807,-9223372036854775808)" ] || { tail -5 "$W/mb.log" >&2; echo "ghc-4.08.2: the driver cannot compile a program" >&2; exit 1; }
for p in concurrent posix util data text; do   # data first-party: text's haxml imports FiniteMap
  MK="HsLibsFor=ghc GHC_INPLACE=$BUILDROOT/w/ghc-4.08.2/$G CC=\"$CCP\" GhcLibsWithReadline=NO SplitObjs=NO GhcLibWays="
  ( cd hslibs/$p && eval make depend $MK > "$W/hslibs-dep-$p.log" 2>&1 && eval make all $MK > "$W/hslibs-mk-$p.log" 2>&1 ) || { grep -aiE 'error|\*\*\*' "$W/hslibs-mk-$p.log" | head -5 >&2; echo "ghc-4.08.2: hslibs/$p failed" >&2; exit 1; }
  [ "$(ar t hslibs/$p/libHS$p.a | wc -l)" -gt 0 ] || { echo "ghc-4.08.2: hslibs/$p archive is empty" >&2; exit 1; }
done

# --- P13 install: the whole working tree, minus scratch, with its absolute paths pointed at the prefix ---
mkdir -p "$DST"
cp -a "$W" "$DST/w"
for d in happyB happyC outB outC tests/run T/comp/obj fakebin; do find "$DST/w/$d" -delete 2>/dev/null || true; done
find "$DST/w" -type f \( -name '*.o' -path '*/T/*' -o -name '*.err' -o -name '*.log' \) -delete
grep -rlI --exclude='*.hc' --exclude='*.hi' "$W" "$DST/w" | xargs -r sed -i "s|$W|$PREFIX/w|g"
grep -rlI "$BUILDROOT" "$DST/w" | grep -v '\.hc$' | head -3 | grep -q . && { echo "ghc-4.08.2: build-root paths remain in the installed tree" >&2; exit 1; } || true
# the next rung's boot compiler: configure parses "version M.mm, patchlevel P"; everything else goes to the driver
mkdir -p "$DST/bin" "$DST/lib"
# the C compiler wrapper the driver runs, with the regenerated libc.so beside it
if [ -f $BIN/gcc ]; then install -m 0755 $BIN/gcc "$DST/bin/"; ln -sf gcc "$DST/bin/cc"; cp -a $BIN/fixlib "$DST/lib/fixlib"; sed -i "s|$BIN/fixlib|$PREFIX/lib/fixlib|" "$DST/bin/gcc"; fi
cat > "$DST/bin/ghc-4.08.2" <<EOF
#!/bin/sh
PATH=$PREFIX/bin:\$PATH; export PATH
case "\$1" in
  --version|-V) echo "The Glorious Glasgow Haskell Compilation System, version 4.08, patchlevel 2"; exit 0 ;;
  --numeric-version) echo 4.08.2; exit 0 ;;
esac
exec $PREFIX/w/ghc-4.08.2/ghc/driver/ghc-unreg "\$@"
EOF
chmod 0755 "$DST/bin/ghc-4.08.2"
echo "ghc-4.08.2: installed $(du -sh "$DST" | cut -f1) at $PREFIX"
