#!/bin/sh
# Build Kani's release bundle offline and install it as a self-contained tree
# at /usr/lib/kani/kani-$version, the layout Kani's own proxies expect under
# KANI_HOME:
#
#   bin/        kani-driver, kani-compiler, kani-cov (+ cbmc/kissat symlinks)
#   lib/ ...    the sysroot libraries kani-compiler built
#   library/    kani's Rust library sources
#   toolchain/  the pinned nightly (kani-compiler is a rustc driver; its rpath
#               is $ORIGIN/../toolchain/lib, and release-mode kani runs
#               toolchain/bin/cargo directly, no rustup)
#
# The nightly lives PRIVATELY under that tree, not in /usr/bin, so kani can sit
# in the same session as rust-nightly-charon (which owns /usr/bin/rustc).
set -eu
# build.ncl's build_args arrive as MINIMAL_ARG_<NAME>.
version="$MINIMAL_ARG_VERSION"
nightly="$MINIMAL_ARG_NIGHTLY"
BUILDROOT=$(pwd)
KDIR="$OUTPUT_DIR/usr/lib/kani/kani-$version"
TC="$KDIR/toolchain"

# 1. The toolchain, from the official component tarballs (extract = false).
mkdir -p "$TC" /tmp/kani-tc
for f in *-nightly-*.tar.xz; do
  tar -xof "$f" -C /tmp/kani-tc
done
for inst in /tmp/kani-tc/*/install.sh; do
  ( cd "$(dirname "$inst")" && ./install.sh --prefix="$TC" --disable-ldconfig )
done
# The installer's manifests carry absolute build paths.
for f in "$TC"/lib/rustlib/manifest-* "$TC"/lib/rustlib/install.log \
         "$TC"/lib/rustlib/rust-installer-version "$TC"/lib/rustlib/uninstall.sh \
         "$TC"/bin/rust-gdb "$TC"/bin/rust-gdbgui "$TC"/bin/rust-lldb; do
  if [ -e "$f" ]; then rm "$f"; fi
done
export PATH="$TC/bin:$PATH"

# rustc-dev ships a second librustc_driver in lib/rustlib/<target>/lib, and
# cargo puts that directory on LD_LIBRARY_PATH for build scripts (which beats
# rustc's RUNPATH). That copy's own $ORIGIN/../lib resolves back into
# rustlib/<target>/lib, which has no libLLVM, so any build script that runs
# `rustc` dies with "libLLVM.so...: cannot open shared object file". Under /usr
# (rust-nightly-charon) /usr/lib on the default search path hides this; in a
# private prefix it is fatal, here and in `cargo kani` at runtime. Link libLLVM
# next to that copy.
for d in "$TC"/lib/rustlib/*/lib; do
  [ -e "$d"/librustc_driver-*.so ] || continue
  for llvm in "$TC"/lib/libLLVM*; do
    ln -s "../../../$(basename "$llvm")" "$d/$(basename "$llvm")"
  done
done

# 2. Offline crates and the charon submodule (kani-deps tarball, see build.ncl).
tar -xof "kani-deps-$version.tar.gz"
cat >> .cargo/config.toml <<'CFG'

[source.crates-io]
replace-with = "vendored-sources"

[source."git+https://github.com/Nadrieril/tracing-tree"]
git = "https://github.com/Nadrieril/tracing-tree"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CFG
# Reproducibility: add the path remap to the config's own rustflags list
# (a RUSTFLAGS env var would replace that list, not extend it).
sed -i "s|^rustflags = \[ # Global lints|rustflags = [ \"--remap-path-prefix=$BUILDROOT=/builddir\", # Global lints|" .cargo/config.toml
grep -q "remap-path-prefix=$BUILDROOT" .cargo/config.toml

export CARGO_HOME="$BUILDROOT/.cargo-home"
export CARGO_NET_OFFLINE=true
# Read at COMPILE time via env!() (the bundle's rust-toolchain-version file,
# kani-driver's toolchain shorthand). kani-compiler's build.rs also unwraps
# RUSTUP_HOME to add a dev-only rpath; a fixed dummy keeps it deterministic.
export RUSTUP_TOOLCHAIN="nightly-$nightly"
export RUSTUP_HOME=/nonexistent-rustup
export CC=gcc
# rustc links build scripts with `cc` by default; the sandbox has gcc only.
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=gcc
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=gcc
# The sysroot-library step runs cargo with -Z host-config, where build scripts
# take their linker from [host] instead.
export CARGO_HOST_LINKER=gcc

# 3. Kani's own bundler: builds the binaries, compiles the sysroot libraries
#    with kani-compiler, and copies cbmc/goto-*/kissat from PATH.
cargo run --release -p build-kani -- bundle "$version"

mkdir -p "$OUTPUT_DIR/usr/lib/kani"
tar -xof kani-"$version"-*.tar.gz -C "$OUTPUT_DIR/usr/lib/kani"

# The bundler COPIES the solver binaries into bin/. Drop them: kani-driver
# runs cbmc, goto-cc, goto-instrument and kissat by bare name, and the proxy
# only PREPENDS bin/ to PATH, so the lookup falls through to the packaged
# /usr/bin copies (runtime_deps). The sandbox rejects absolute symlinks.
for b in cbmc goto-instrument goto-cc goto-analyzer kissat; do
  rm "$KDIR/bin/$b"
done

# 4. The `kani` / `cargo-kani` proxies (kani-verifier's bins), plus PATH
#    wrappers that point them at this tree. Without KANI_HOME they would look
#    in ~/.kani and try to download a bundle.
mkdir -p "$OUTPUT_DIR/usr/lib/kani/proxy" "$OUTPUT_DIR/usr/bin"
cp target/kani/bin/kani target/kani/bin/cargo-kani "$OUTPUT_DIR/usr/lib/kani/proxy/"
for b in kani cargo-kani; do
  cat > "$OUTPUT_DIR/usr/bin/$b" <<WRAP
#!/bin/sh
export KANI_HOME="\${KANI_HOME:-/usr/lib/kani}"
# Build scripts and proc-macros in the crate under test are linked by rustc,
# which defaults to \`cc\`; Minimal ships gcc under its own name.
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="\${CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER:-gcc}"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="\${CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER:-gcc}"
exec /usr/lib/kani/proxy/$b "\$@"
WRAP
  chmod 755 "$OUTPUT_DIR/usr/bin/$b"
done
