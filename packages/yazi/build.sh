#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# yazi 26.8+ embeds a build-time git SHA: yazi-version/build.rs runs vergen,
# which needs a `.git` dir + `git` binary. Our hermetic build is a tarball
# extract with neither, so vergen warns "Unable to set VERGEN_GIT_SHA" and emits
# nothing — then `env!("VERGEN_GIT_SHA")` in yazi-version/src/lib.rs is a
# compile-time hard error. Provide it in the environment (env! reads the ambient
# process env when the build script sets nothing). Fixed, not the real commit,
# so two builds stay byte-identical; `yazi --version` reports the release.
export VERGEN_GIT_SHA="v${MINIMAL_ARG_VERSION}"

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    if [ -f /cargo-vendor/.cargo-config.toml ]; then
        cp /cargo-vendor/.cargo-config.toml .cargo/config.toml
    else
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    fi
    cargo build --offline --frozen --release --locked
else
    cargo build --release --locked
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/yazi $OUTPUT_DIR/usr/bin
