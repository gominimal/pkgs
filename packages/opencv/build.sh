#!/bin/sh
set -e

# Create build directory
mkdir -p build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Configure.
#
# Image codecs come from the registry, not from opencv's 3rdparty/ copies.
# The copies are compiled as static archives into libopencv_imgcodecs, where
# no scanner sees them, and at 4.14.0 two are older than our packages
# (bundled libpng 1.6.57, libjpeg-turbo 3.1.2). The BUILD_*=OFF switches are
# already the Linux default and do NOT stop the fallback: opencv builds the
# bundled copy whenever find_package fails (cmake/OpenCVFindLibsGrfmt.cmake),
# which is what happened while these libraries were not build deps. The
# checks after the build are what make this fail closed.
#
# - openjpeg: WITH_OPENJPEG=ON + BUILD_OPENJPEG=OFF links our openjpeg instead
#   of 3rdparty/openjpeg. The bundled copy is what OSS-Fuzz flagged as
#   OSV-2023-444 (heap-overflow in opj_jp2_apply_pclr); the system lib carries
#   the upstream fix (OpenJPEG PR #1441, shipped in 2.5.1+), so this removes
#   the vulnerable code rather than asserting the vendored copy is patched.
# - zlib, libpng, libjpeg-turbo, libwebp: our packages.
# - libtiff: still the bundled 4.7.1 copy. The registry has no libtiff
#   package yet. The check below expects the bundled copy, so moving to a
#   libtiff package has to change it on purpose.
# - OpenEXR: off. The registry has no OpenEXR, and the bundled copy is
#   OpenEXR 2.3.0 (2018) with a long OSS-Fuzz CVE tail. EXR decoding was
#   already opt-in at runtime (OPENCV_IO_ENABLE_OPENEXR).
# - IPP: off. On x86_64, WITH_IPP downloads Intel's prebuilt IPPICV archive
#   at configure time (3rdparty/ippicv/ippicv.cmake, md5-pinned only) and
#   links it statically into libopencv_core: a binary we did not build,
#   under Intel's licence rather than Apache-2.0, fetched outside the
#   recipe's sha256-pinned sources. arm64 never had it. The x86 imgproc
#   kernels IPP accelerated fall back to opencv's own SIMD code.
#
# Protobuf (dnn) is still the bundled copy: a follow-up, because opencv's
# pregenerated .pb.cc files are for protobuf 3.19 and ours is 36.x.
#
# Tests, perf tests, examples and docs: off. BUILD_TESTS and BUILD_PERF_TESTS
# default to ON, so every build compiled the opencv_test_* / opencv_perf_*
# binaries (and the ts module they need) that no output ships and no test
# here runs. Examples and docs already default to OFF; they are set so an
# upstream default change cannot bring them back. The apps (opencv_version,
# opencv_annotation, ...) are BUILD_opencv_apps, which stays on.
cmake -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr         \
        -DOPENCV_GENERATE_PKGCONFIG=ON      \
        -DOPENCV_LIB_INSTALL_PATH=/usr/lib  \
        -DWITH_OPENJPEG=ON                  \
        -DBUILD_OPENJPEG=OFF                \
        -DBUILD_ZLIB=OFF                    \
        -DBUILD_PNG=OFF                     \
        -DBUILD_JPEG=OFF                    \
        -DBUILD_WEBP=OFF                    \
        -DWITH_OPENEXR=OFF                  \
        -DWITH_IPP=OFF                      \
        -DBUILD_TESTS=OFF                   \
        -DBUILD_PERF_TESTS=OFF              \
        -DBUILD_EXAMPLES=OFF                \
        -DBUILD_DOCS=OFF                    \
        ../opencv-$MINIMAL_ARG_VERSION

# Build
ninja -j"$(nproc)"

# Fail closed: opencv built no bundled copy of a library we now take from the
# registry. Every 3rdparty static archive lands in 3rdparty/lib; the bundled
# libtiff, which stays, proves that is still where to look.
[ -f 3rdparty/lib/liblibtiff.a ] || {
  echo "ERROR: 3rdparty/lib/liblibtiff.a is missing: opencv moved its 3rdparty archives, or libtiff is no longer bundled. Update this check." >&2
  exit 1
}
for a in libzlib liblibpng liblibjpeg-turbo liblibwebp liblibopenjp2 libIlmImf; do
  if [ -e "3rdparty/lib/$a.a" ]; then
    echo "ERROR: opencv built its bundled copy 3rdparty/lib/$a.a instead of using the package" >&2
    exit 1
  fi
done

DESTDIR="$OUTPUT_DIR" ninja install

# Fail closed: BUILD_TESTS / BUILD_PERF_TESTS really are off (no test binary
# was built, none was installed).
for t in bin/opencv_test_* bin/opencv_perf_* "$OUTPUT_DIR"/usr/bin/opencv_test_* "$OUTPUT_DIR"/usr/bin/opencv_perf_*; do
  if [ -e "$t" ]; then
    echo "ERROR: $t was built although BUILD_TESTS and BUILD_PERF_TESTS are OFF" >&2
    exit 1
  fi
done

# Fail closed: libopencv_imgcodecs, which holds the codecs, links the
# registry's shared libraries.
command -v readelf >/dev/null
imgcodecs=$(find "$OUTPUT_DIR/usr/lib" -name 'libopencv_imgcodecs.so.*' ! -type l | head -n 1)
[ -n "$imgcodecs" ] || { echo "ERROR: libopencv_imgcodecs.so.* not installed" >&2; exit 1; }
needed=$(readelf -d "$imgcodecs" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
for lib in libz.so libpng16.so libjpeg.so libwebp.so libopenjp2.so; do
  if ! printf '%s\n' "$needed" | grep -q "^$lib\."; then
    echo "ERROR: $imgcodecs has no DT_NEEDED on $lib. NEEDED:" >&2
    printf '  %s\n' $needed >&2
    exit 1
  fi
done
