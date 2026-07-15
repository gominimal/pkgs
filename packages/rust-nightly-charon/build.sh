#!/bin/sh
# Assemble the nightly-2026-06-01 rustc-dev sysroot from the official component
# tarballs (mirrored to gs://). Each tarball ships an `install.sh` that lays its
# payload into a --prefix; we install them all into one usr/ tree.
set -eu
DEST="$OUTPUT_DIR/usr"
mkdir -p "$DEST"
# The Source deps land as raw *.tar.xz files in the build cwd (extract = false).
for f in *.tar.xz; do
  tar -xof "$f"
done
# Run each component's installer into the shared prefix. --disable-ldconfig:
# the build sandbox has no ldconfig and the sysroot is relocatable anyway.
for inst in */install.sh; do
  d=$(dirname "$inst")
  ( cd "$d" && ./install.sh --prefix="$DEST" --disable-ldconfig )
done
# Drop the debug/doc wrapper SCRIPTS we don't ship — rust-gdb/rust-lldb/
# rust-gdbgui are shell wrappers; charon just needs rustc + cargo + rustdoc.
rm -f "$DEST"/bin/rust-gdb "$DEST"/bin/rust-gdbgui "$DEST"/bin/rust-lldb
# The installer writes an uninstall manifest carrying absolute build paths — drop
# those files so two builds are byte-identical and no sandbox path leaks.
rm -f "$DEST"/lib/rustlib/manifest-* "$DEST"/lib/rustlib/install.log \
      "$DEST"/lib/rustlib/rust-installer-version "$DEST"/lib/rustlib/uninstall.sh 2>/dev/null || true
