#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# All third-party deps (luajit, libuv, luv, lpeg, unibilium, utf8proc,
# tree-sitter and the grammar parsers) come from the registry, so upstream's
# cmake.deps download step is skipped entirely.
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
# Reproducibility: the API metadata blob baked into nvim (funcs_metadata, the
# msgpack that `nvim --api-info` prints) is produced by gen_api_dispatch.lua,
# which packs Lua tables in LuaJIT's table-iteration order. LuaJIT seeds its
# string hash per process from syscall(SYS_getrandom) (src/lj_prng.c), so two
# builds order the maps differently (2026-10 world-rebuild pairs: 74 KB of
# .rodata). Interpose the entropy sources for the BUILD only, the same shim
# zola/nushell/codex use plus the raw-syscall path LuaJIT takes. The produced
# nvim is unaffected: it is not linked against this.
cat > /tmp/detrand.c <<'SHIM'
#define _GNU_SOURCE
#include <stdarg.h>
#include <stddef.h>
#include <dlfcn.h>
#include <sys/syscall.h>
#include <sys/types.h>
ssize_t getrandom(void *buf, size_t n, unsigned int flags) {
    unsigned char *p = buf; size_t i;
    for (i = 0; i < n; i++) p[i] = (unsigned char)(0xA5 ^ (i * 157));
    return (ssize_t)n;
}
int getentropy(void *buf, size_t n) { getrandom(buf, n, 0); return 0; }
long syscall(long nr, ...) {
    static long (*real)(long, ...);
    long a[6]; int i; va_list ap;
    va_start(ap, nr); for (i = 0; i < 6; i++) a[i] = va_arg(ap, long); va_end(ap);
    if (nr == SYS_getrandom) return getrandom((void *)a[0], (size_t)a[1], (unsigned int)a[2]);
    if (!real) real = dlsym(RTLD_NEXT, "syscall");
    return real(nr, a[0], a[1], a[2], a[3], a[4], a[5]);
}
SHIM
gcc -shared -fPIC -O2 -o /tmp/detrand.so /tmp/detrand.c
LD_PRELOAD=/tmp/detrand.so cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
