#!/bin/bash
set -euo pipefail

cd codex-rs

export CC=gcc
export LD=gcc
# codegen-units=1 and v0 mangling: with the default parallel codegen the binary came
# out different on every build (2026-10 prod-pair diff: 36 of 36 differing symbols were
# `.llvm.<hash>` codegen-unit locals, 49% of the 1.25 GB binary churned). The same two
# flags fixed nushell and difftastic (gominimal/inbox#253).
export RUSTFLAGS="-C linker=gcc -C codegen-units=1 -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir"

# Needed for crates that use bindgen / libclang
export LIBCLANG_PATH="$(dirname $(find /usr/lib -name 'libclang*.so' | head -1))"

# Deterministic build-time entropy, the shim zola and nushell already use: interposes
# getrandom/getentropy so build.rs / proc-macro / rustc-internal HashMaps iterate in the
# same order every build. It wraps only the BUILD; the produced binaries are unaffected.
cat > /tmp/detrand.c <<'SHIM'
#include <stddef.h>
#include <sys/types.h>
ssize_t getrandom(void *buf, size_t n, unsigned int flags) {
    unsigned char *p = buf; size_t i;
    for (i = 0; i < n; i++) p[i] = (unsigned char)(0xA5 ^ (i * 157));
    return (ssize_t)n;
}
int getentropy(void *buf, size_t n) { getrandom(buf, n, 0); return 0; }
SHIM
gcc -shared -fPIC -O2 -o /tmp/detrand.so /tmp/detrand.c
LD_PRELOAD=/tmp/detrand.so cargo build --release -p codex-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex
