#!/bin/sh
set -ex

# Kissat's build header bakes in `date`, `uname -srmn` (the build host's
# name) and the build directory, and the makefile marks build.h .PHONY, so it
# is regenerated on every make. Replace the generator with fixed values; the
# version still comes from VERSION, so `kissat --version` is unchanged.
cat > scripts/generate-build-header.sh <<'HDR'
#!/bin/sh
v="$(cat ../VERSION)"
cat <<H
#define VERSION "$v"
#define COMPILER "gcc"
#define ID "rel-$v"
#define BUILD "minimal"
#define DIR "/builddir"
H
HDR
chmod +x scripts/generate-build-header.sh

CC=gcc ./configure
# configure resets CFLAGS, so the reproducibility flags go on the generated
# makefile's compiler and linker lines.
sed -i \
  -e "s|^CC=\(.*\)|CC=\1 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches|" \
  -e "s|^LD=\(.*\)|LD=\1 -Wl,--build-id=none|" \
  build/makefile
make -C build -j"$(nproc)" kissat

mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/kissat "$OUTPUT_DIR/usr/bin/kissat"
