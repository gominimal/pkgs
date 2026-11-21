#!/bin/bash
set -euo pipefail

V="${MINIMAL_ARG_VERSION:?build.ncl forwards version}"
# Both sources are the crates.io .crate files, not GitHub tag archives: each
# carries the Cargo.lock `cargo publish` resolved, so --locked builds exactly
# the tree upstream released.
tar -xzof "gungraun-runner-$V.crate"
tar -xzof "gungraun-$V.crate"
top=$(pwd)

export CC=gcc
export LD=gcc
# Reproducibility: codegen-units=1 and v0 mangling (see cargo-mutants), plus the
# source and cargo-home paths remapped out of the binary.
export RUSTFLAGS="-C linker=gcc -C codegen-units=1 -C symbol-mangling-version=v0 --remap-path-prefix=$top=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0

# ---------------------------------------------------------------------------
# The self-test project (run after the runner is installed, below). It is a
# one-benchmark crate that depends on the gungraun LIBRARY from the second
# Source, with gungraun-runner patched to the runner source we build, so the
# harness and the runner are the same release by construction.
#
# Its lock is seeded with the gungraun library's published Cargo.lock. cargo
# then keeps every version in it and only drops what the bench does not use
# (gungraun's dev-deps) and adds the bench itself; the check after the fetch
# fails the build if any registry crate is not pinned by that published lock.
selftest="$top/gungraun-selftest"
mkdir -p "$selftest/benches"
cat > "$selftest/Cargo.toml" <<EOF
[package]
name = "gungraun-selftest"
version = "0.0.0"
edition = "2021"
publish = false

[dev-dependencies]
gungraun = { path = "$top/gungraun-$V" }

[patch.crates-io]
gungraun-runner = { path = "$top/gungraun-runner-$V" }

[[bench]]
name = "fib"
harness = false
EOF
cat > "$selftest/benches/fib.rs" <<'EOF'
use std::hint::black_box;

use gungraun::prelude::*;

fn fib(n: u64) -> u64 {
    if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
}

#[library_benchmark]
#[bench::twenty(20)]
fn bench_fib(n: u64) -> u64 {
    black_box(fib(black_box(n)))
}

library_benchmark_group!(name = fib_group, benchmarks = bench_fib);
main!(library_benchmark_groups = fib_group);
EOF
cp "gungraun-$V/Cargo.lock" "$selftest/Cargo.lock"
mkdir -p "$selftest/src" && : > "$selftest/src/lib.rs"

# All network access happens here, with real entropy, before the detbuild
# preload. gungraun-runner has no -sys crate and no build script that
# downloads anything (checked for 0.20.0); the self-test's tree is the same
# plus gungraun's proc macros.
(cd "gungraun-runner-$V" && cargo fetch --locked)
(cd "$selftest" && cargo fetch)

registry_pairs() {
  awk '/^\[\[package\]\]/{n="";v=""} /^name = /{n=$3} /^version = /{v=$3} /^source = "registry\+/{print n, v}' "$1" | sort -u
}
unpinned=$(comm -13 <(registry_pairs "gungraun-$V/Cargo.lock") <(registry_pairs "$selftest/Cargo.lock"))
if [ -n "$unpinned" ]; then
  echo "ERROR: the self-test resolved registry crates gungraun $V's published Cargo.lock does not pin:" >&2
  echo "$unpinned" >&2
  exit 1
fi

# Deterministic build-time entropy (packages/detbuild) for the offline build
# of what ships; `--frozen` refuses any network access.
(cd "gungraun-runner-$V" && LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release --bin gungraun-runner)

install -Dm755 "gungraun-runner-$V/target/release/gungraun-runner" "$OUTPUT_DIR/usr/bin/gungraun-runner"

# runtime_deps is glibc + libgcc (libgcc_s, for unwinding) + valgrind; fail
# closed if the binary ever NEEDs anything else.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/gungraun-runner" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
echo "$needed"
if grep -vxE 'libc\.so\.6|libm\.so\.6|libgcc_s\.so\.1|ld-linux-(x86-64|aarch64)\.so\.[12]' <<<"$needed"; then
  echo "ERROR: gungraun-runner NEEDs a library outside glibc and libgcc_s (above)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Self-test: a real benchmark, run by the binary just installed, under the
# valgrind this package depends on (a runtime dep, so it is in this sandbox).
# This runs here rather than as a standalone test because a standalone test
# has no crates: building any gungraun benchmark needs the library and its
# proc-macro tree from crates.io, and only the build may fetch. Nothing from
# it is installed.
#
# The library finds the runner on PATH (no GUNGRAUN_RUNNER at compile time)
# and refuses a runner whose version differs from its own, so this also checks
# the lookup and the version handshake users depend on.
export PATH="$OUTPUT_DIR/usr/bin:$PATH"
export GUNGRAUN_COLOR=never
# Everything is fetched; the runner's own `cargo metadata` must not go online.
export CARGO_NET_OFFLINE=true
cd "$selftest"

# runner output: "  Instructions:   <n>|N/A   (*********)" per benchmark; the
# raw Callgrind/Cachegrind files land under target/gungraun.
has_out() { [ -n "$(find target/gungraun -type f -name "$1" -size +0 -print -quit)" ]; }

out=$(cargo bench --frozen --bench fib 2>&1) || { echo "$out" >&2; echo "ERROR: callgrind benchmark failed" >&2; exit 1; }
echo "$out"
grep -Eq 'Instructions: +[1-9][0-9]*' <<<"$out" || { echo "ERROR: no Callgrind instruction count in the benchmark output" >&2; exit 1; }
has_out 'callgrind.*.out' || { echo "ERROR: no callgrind output file under target/gungraun" >&2; exit 1; }

out=$(GUNGRAUN_DEFAULT_TOOL=cachegrind cargo bench --frozen --bench fib 2>&1) || { echo "$out" >&2; echo "ERROR: cachegrind benchmark failed" >&2; exit 1; }
echo "$out"
has_out 'cachegrind.*.out' || { echo "ERROR: no cachegrind output file under target/gungraun" >&2; exit 1; }
find target/gungraun -type f | sort
