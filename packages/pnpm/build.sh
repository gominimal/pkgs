#!/bin/sh
set -e

# pnpm 12 is a native (Rust) binary. The npm `pnpm` tarball is only a wrapper
# around it: its `pnpm` file is an sh placeholder that hands over to
# bin/pnpm.mjs, which runs the binary from `@pnpm/exe.<os>-<arch>` or, failing
# that, DOWNLOADS one from the registry on first use. Neither the placeholder
# nor that downloader may ship here. Instead reproduce the layout npm's own
# install script (package/install.js) produces: the wrapper directory, with
# the native binary placed over the `pnpm` placeholder.
#
# That layout is load-bearing, not cosmetic: the binary finds the node-gyp it
# puts on lifecycle scripts' PATH at `<dir of current_exe>/dist/node-gyp-bin`
# (crates/executor/src/bundled_node_gyp.rs), so dist/ must sit beside it.

case $(uname -m) in
  x86_64)  PNPMARCH=x64 ;;
  aarch64) PNPMARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

mkdir wrapper native
tar -xof "pnpm-${MINIMAL_ARG_VERSION}.tgz" -C wrapper
tar -xof "exe.linux-${PNPMARCH}-${MINIMAL_ARG_VERSION}.tgz" -C native

PREFIX=$OUTPUT_DIR/usr/libexec/pnpm
install -d $OUTPUT_DIR/usr/bin $PREFIX

# The wrapper's payload: dist/ (node-gyp + node-gyp-bin), the Unix alias
# scripts, license + notices. Deliberately NOT bin/*.mjs, install.js or
# native-binary.mjs (the Corepack / install-time path that downloads a binary),
# and not dist/node_modules/get-pnpm, the downloader they call, which nothing
# else in dist/ uses.
cp -R wrapper/package/dist $PREFIX/dist
rm -rf $PREFIX/dist/node_modules/get-pnpm
for f in pn pnpx pnx package.json README.md THIRD-PARTY-NOTICES.md; do
  cp wrapper/package/$f $PREFIX/$f
done
cp native/package/LICENSE $PREFIX/LICENSE

# The native binary, where install.js puts it: over the `pnpm` placeholder.
install -m 755 native/package/pnpm $PREFIX/pnpm

# `pn` is pnpm; `pnpx`/`pnx` are `pnpm dlx`. Upstream ships them as sh scripts
# that resolve their own symlink chain and exec the `pnpm` beside them (the
# binary only infers `dlx` from current_exe(), which a symlink cannot change).
for b in pnpm pn pnpx pnx; do
  ln -s ../libexec/pnpm/$b $OUTPUT_DIR/usr/bin/$b
  test -x $OUTPUT_DIR/usr/bin/$b || { echo "pnpm: $b is not executable" >&2; exit 1; }
done

# The payload the binary looks for must be where it looks.
test -f $PREFIX/dist/node-gyp-bin/node-gyp \
  || { echo "pnpm: dist/node-gyp-bin/node-gyp missing beside the binary" >&2; exit 1; }

# Prove the binary itself is what runs (not a placeholder), at the right version.
got=$($PREFIX/pnpm --version)
test "$got" = "$MINIMAL_ARG_VERSION" \
  || { echo "pnpm: --version printed '$got', expected $MINIMAL_ARG_VERSION" >&2; exit 1; }
