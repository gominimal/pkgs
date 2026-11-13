#!/bin/sh
set -ex

# The sandbox has no `cc` symlink, so force gcc for both cargo's cc-rs builds
# and the init blob compiled by init_blob/build.rs.
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# vsock fixes (see build.ncl). Applied by explicit name, not by glob. `set -e`
# plus patch's non-zero exit on a rejected hunk makes a stale patch abort the
# build; a silently-skipped patch would publish a libkrun that looks fixed and
# is not. -F0: patch's default fuzz 2 lets a hunk whose context went stale
# apply somewhere else and still succeed (0001's update_peer_credit hunk did
# against 1.19.7, gominimal/pkgs#1018), so a stale hunk must fail instead.
patch -F0 -Np1 -i "0001-vsock-bound-outstanding-packets.patch"
patch -F0 -Np1 -i "0002-vsock-refuse-stream-when-unix-proxy-creation-fails.patch"

# BLK=1 enables virtio-blk (exports krun_add_disk2); `blk` is not a default
# libkrun feature, so consumers fail to link without it.
make CC=gcc BLK=1 -j"$(nproc)"
# Install to lib (not the Makefile's default lib64), matching the repo convention.
make CC=gcc BLK=1 install PREFIX=/usr DESTDIR="$OUTPUT_DIR" LIBDIR_Linux=lib
