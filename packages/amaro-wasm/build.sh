#!/bin/sh
set -ex

RV="${MINIMAL_ARG_RUST_VERSION:?build.ncl forwards rust_version}"
VERSIONS="${MINIMAL_ARG_AMARO_VERSIONS:?build.ncl forwards amaro_versions}"
TOP=$(pwd)

# std for wasm32 comes from the rustc source of the exact rustc in use.
case "$(rustc --version)" in "rustc $RV "*) ;; *) echo "rustc is not $RV: update rust_version and its sha" >&2; exit 1 ;; esac
tar -xof "rustc-$RV-src.tar.xz" "rustc-$RV-src/library"
LIB="$TOP/rustc-$RV-src/library"
export __CARGO_TESTS_ONLY_SRC_ROOT="$LIB"
export RUSTC_BOOTSTRAP=1

# Host artifacts (build scripts, proc macros) link with gcc; swc's .cargo/config.toml names
# cross linkers for the linux targets.
export CC=gcc
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=gcc
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=gcc
export CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER=wasm-ld
# amaro's swc scripts/build.sh
export CARGO_PROFILE_RELEASE_LTO=fat
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z

# build <amaro version> <work dir>: the module amaro's tools/build-wasm.js produces, as
# <work dir>/pkg/wasm_bg.wasm (before patch.mjs inlines it).
build() {
  v=$1; w=$2
  rm -rf "$w"; mkdir -p "$w"
  tar -xof "$TOP/v$v.tar.gz" -C "$w" "amaro-$v/deps/swc"
  # From the binding's directory, as wasm-pack runs it, so its .cargo/config.toml (the 2 MiB
  # stack) applies along with the workspace's; the stack size is repeated in case the env value
  # replaces rather than extends it.
  cd "$w/amaro-$v/deps/swc/bindings/binding_typescript_wasm"
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS="-Clink-arg=-zstack-size=2097152 --remap-path-prefix=$w=/builddir --remap-path-prefix=$LIB=/rustc/library --remap-path-prefix=$HOME/.cargo=/cargo" \
    cargo build --release --locked -Zbuild-std=std,panic_abort --target wasm32-unknown-unknown
  cd "$w/amaro-$v/deps/swc"
  wasm-bindgen --target nodejs --out-name wasm --out-dir pkg --typescript \
    target/wasm32-unknown-unknown/release/binding_typescript_wasm.wasm
  cd "$TOP"
}

for v in $VERSIONS; do
  # Built twice, at different paths: the module must not depend on where it was built.
  build "$v" "$TOP/a-$v"
  build "$v" "$TOP/b-$v"
  A="$TOP/a-$v/amaro-$v/deps/swc/pkg/wasm_bg.wasm"
  B="$TOP/b-$v/amaro-$v/deps/swc/pkg/wasm_bg.wasm"
  cmp "$A" "$B" || { echo "amaro $v: two builds of wasm_bg.wasm differ" >&2; exit 1; }
  D="$OUTPUT_DIR/usr/share/amaro-wasm/$v"
  mkdir -p "$D"
  cp "$A" "$D/wasm_bg.wasm"
  cp "$TOP/a-$v/amaro-$v/deps/swc/pkg/wasm.js" "$D/wasm.js"
  sha256sum "$D/wasm_bg.wasm"
done
