#!/bin/bash
set -euo pipefail

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# valkey's default OPTIMIZATION (-O3) gets -flto=auto appended. The aarch64 bedrock
# toolchain ships without LTO (see packages/redis/build.sh), so there OPTIMIZATION is set
# on the command line, which drops the appended -flto. -fno-omit-frame-pointer is what
# upstream appends to every non -O0 build; keep it on both arches.
case "$(uname -m)" in
  aarch64) OPT=(OPTIMIZATION="-O3 -fno-omit-frame-pointer") ;;
  *)       OPT=() ;;
esac

# MALLOC=libc, like packages/redis: the jemalloc in deps/ is a vendored, patched copy
# (valkey has no option to use a system jemalloc), and one allocator in both keeps a
# redis-vs-valkey comparison about the server, not the allocator. The cost is that
# active defragmentation (activedefrag) is unavailable; it needs jemalloc.
# BUILD_TLS is left off (the default), like redis. USE_SYSTEMD=no: no libsystemd is
# packaged; without it the Makefile probes for one with pkg-config.
#
# USE_REDIS_SYMLINKS=no: by default `make install` also creates redis-server,
# redis-cli, redis-benchmark, redis-check-aof, redis-check-rdb and redis-sentinel
# symlinks to the valkey binaries. Those are paths packages/redis ships, so they are
# not installed, and valkey and redis can be in one closure.
make -j"$(nproc)" V=1 MALLOC=libc USE_SYSTEMD=no USE_REDIS_SYMLINKS=no "${OPT[@]}"
make V=1 MALLOC=libc USE_SYSTEMD=no USE_REDIS_SYMLINKS=no "${OPT[@]}" PREFIX="$OUTPUT_DIR/usr" install

# Fail closed on a redis-* name reaching the output: a renamed knob upstream would
# otherwise bring the compat links back and collide with packages/redis.
if find "$OUTPUT_DIR" -name 'redis*' | grep .; then
  echo "ERROR: redis-named files in the output; they collide with packages/redis" >&2
  exit 1
fi
ls -l "$OUTPUT_DIR/usr/bin"
sha256sum "$OUTPUT_DIR"/usr/bin/valkey-{server,cli,benchmark}
readelf -d "$OUTPUT_DIR/usr/bin/valkey-server" | grep NEEDED
