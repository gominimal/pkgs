#!/bin/bash
# microhs-0.16: the root of the source-only GHC ladder. MicroHs is a small Haskell compiler written in Haskell and
# shipped with its own compiled form as portable C (generated/mhs.c, generated/cpphs.c — combinator code for the
# interpreter in src/runtime), so gcc alone produces a working Haskell compiler. GHC 4.08.2's hsc runs on it.
# phases: P0 preconditions, P1 patches, P2 build, P3 install at /usr/lib/microhs-0.16, P4 gate.
set -euo pipefail
trap 'echo "microhs-0.16: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
VERSION=0.16.0.0
PREFIX=/usr/lib/microhs-0.16
DST="${OUTPUT_DIR}${PREFIX}"
BIN=$PWD/bin

# --- C toolchain: the bedrock gcc against the versioned glibc sysroot (as every rung of the GHC ladder) ---
SR=/usr/lib/glibc-bedrock-2.42; LOADER=$SR/lib/ld-linux-x86-64.so.2
[ -e $SR/lib/libc.so ] && [ -e $LOADER ] || { echo "microhs-0.16: glibc sysroot missing at $SR" >&2; exit 1; }
mkdir -p $BIN/fixlib
# the sysroot's libc.so is a linker script with staging paths; regenerate it
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@$SR/lib/\1@g" $SR/lib/libc.so > $BIN/fixlib/libc.so
grep -q '/build/output' $BIN/fixlib/libc.so && { echo "microhs-0.16: libc.so fixup failed" >&2; exit 1; }
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
for f in Makefile generated/mhs.c generated/cpphs.c src/runtime/eval.c lib/Data/Integer_Type.hs; do
  [ -f "$f" ] || { echo "microhs-0.16: $f missing from the source tree" >&2; exit 1; }
done

# --- P1 patches: GHC 4.08 relies on wrap-around Int arithmetic; MicroHs traps on overflow by default ---
# eval-wrap: quot/neg wrap in the evaluator and WANT_OVERFLOW 0 in the unix config;
# lib-wrap: the narrow Int/Word types and Bits shifts wrap instead of trapping;
# integer-type: Int -> Integer conversion through unsigned digits (no signed overflow on minBound).
for p in eval-wrap lib-wrap integer-type; do patch -p1 --no-backup-if-mismatch < "$p.patch"; done
grep -q 'WANT_OVERFLOW 0' src/runtime/unix/config.h || { echo "microhs-0.16: eval-wrap did not apply" >&2; exit 1; }

# --- P2: the two interpreter binaries; the Makefile compiles the shipped combinator C with $(CC) ---
export CFLAGS="-O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
make CC=gcc CCOPTS="$CFLAGS" bin/mhs bin/cpphs

# --- P3 install: the source tree's in-place layout. mhs treats itself as in place when <bin>/../src/runtime/eval.c
# exists and then reads its library from <bin>/../lib; the runtime C sources are also what `mhs -o` links a program's
# generated C against, so they ship. mhs.conf carries the C compiler flags for that step.
mkdir -p "$DST/bin" "$DST/lib" "$DST/src"
install -m 0755 bin/mhs bin/cpphs "$DST/bin/"
cp -a lib/. "$DST/lib/"
cp -a src/runtime "$DST/src/runtime"
cp mhs.conf "$DST/"

# --- P4 gate: compile and run a program with the installed compiler (its lib resolves relative to the binary) ---
G=$(mktemp -d)
printf 'module Main where\nmain :: IO ()\nmain = print (sum [1 .. 100 :: Int], product [1 .. 25 :: Integer], (minBound :: Int) - 1)\n' > "$G/Main.hs"
( cd "$G" && "$DST/bin/mhs" Main -o prog && ./prog > out )
grep -qx '(5050,15511210043330985984000000,9223372036854775807)' "$G/out" || { echo "microhs-0.16: gate program output wrong: $(cat "$G/out")" >&2; exit 1; }
"$DST/bin/cpphs" --version > /dev/null
