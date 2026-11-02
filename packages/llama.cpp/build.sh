#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# The embedded web UI (llama-ui, linked into libllama-server-impl.so). Left to
# itself, scripts/ui-assets.cmake downloads dist.tar.gz from Hugging Face at build
# time, and with no .git in the tarball the build number is 0, so it falls back to
# the moving `latest` tag: a different UI got embedded as upstream published new
# ones, which was the 2026-10 prod-pair diff (31% of libllama-server-impl.so,
# identical symbols). Instead, the b11960 UI is a pinned Source, unpacked where the
# script looks first (tools/ui/dist), and both fetch paths are off. The script
# gzips each asset without -n, so the gzip header carries the file's mtime: pin
# the mtimes too. Not to SOURCE_DATE_EPOCH: the sandbox's is 0, which gzip can't
# store ("file timestamp out of range", exit 2), so 1980-01-01 instead.
mkdir -p tools/ui/dist
tar -xof "${MINIMAL_ARG_VERSION}-dist.tar.gz" -C tools/ui/dist
test -s tools/ui/dist/index.html || {
  echo "ERROR: pinned llama-ui dist has no index.html" >&2
  exit 1
}
find tools/ui/dist -exec touch -h -d @315532800 {} +

# GGML_NATIVE=OFF is a guard: ggml already defaults it OFF when SOURCE_DATE_EPOCH is
# set (the sandbox sets it), and -march=native would make the code follow the build
# host's CPU instead of the explicit $MARCH in CFLAGS.
cmake -B build -DGGML_NATIVE=OFF -DLLAMA_BUILD_UI=OFF -DLLAMA_USE_PREBUILT_UI=OFF
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

install -vm755 build/bin/*.so $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
