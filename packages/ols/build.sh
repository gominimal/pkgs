#!/bin/sh
set -ex

# The upstream tarball ships its own build.sh at the repo root, so it is left
# packed under its own directory rather than extracted over ours.
cd "ols-$MINIMAL_ARG_VERSION"

# odin dev-2026-11 changed io.write_quoted_string's last parameter from a bool to
# a bit_set; upstream 78bf891 (after dev-2026-10) adapts ols to it. Once the
# release we build already contains that fix, the patch is redundant: fail here
# with a clear message so the bump drops it, rather than at a confusing reject.
if grep -q 'json.write_quoted_json_string' src/server/marshal.odin; then
  echo "ols $MINIMAL_ARG_VERSION already contains upstream 78bf891: drop ols-write-quoted-json-string.patch from build.ncl and build.sh" >&2
  exit 1
fi
patch -Np1 -i ../ols-write-quoted-json-string.patch
# patch exits 0 on fuzz too; assert both old bool-taking calls are gone.
if grep -n "write_quoted_string(.*, true)" src/server/marshal.odin; then exit 1; fi

# Upstream's build.sh is not usable as-is: it stamps VERSION from `date -u` plus
# `git rev-parse HEAD` (no wall clock in a reproducible build, and no .git here)
# and compiles with -microarch:native, which bakes the builder's CPU into the
# binary. Everything else below matches the flags it and ci.sh use.
#
# Two more things are needed to make odin's own output reproducible, and both
# have to be right or the binaries differ between builds:
#
#   -no-threaded-checker  The compiler assigns entity ids from a global counter
#                         as it checks, and those ids order the procedures in
#                         the emitted module. Off the flag, the work is spread
#                         over a thread pool and the order is a race. The odin
#                         package patches this flag to drop the pool to zero
#                         workers so parsing and codegen serialise with it.
#   setarch -R            Odin walks pointer-keyed hash maps during codegen, so
#                         the emitted order also follows heap addresses. With
#                         ASLR on those move every run; disabling it for the
#                         compiler process pins them.
#
# --build-id=none: odin links through clang, whose default build-id is derived
# from the output hash and so differs whenever anything else does.
LINK_FLAGS='-Wl,--build-id=none'

odin_build() {
  setarch --addr-no-randomize odin build "$@" \
    -collection:src=src \
    -o:speed \
    -no-bounds-check \
    -no-threaded-checker \
    -extra-linker-flags:"$LINK_FLAGS"
}

odin_build src/ -out:ols -define:VERSION="$MINIMAL_ARG_VERSION"

# odinfmt is the formatter half of the project; upstream's release archives ship
# it alongside ols, and the LSP's formatting request is a thin wrapper over the
# same code, so users configuring format-on-save want the CLI too.
odin_build tools/odinfmt/main.odin -file -out:odinfmt

install -D -m 0755 ols      "$OUTPUT_DIR/usr/bin/ols"
install -D -m 0755 odinfmt  "$OUTPUT_DIR/usr/bin/odinfmt"

# ols searches for the builtin declarations next to its own binary first and
# then at this fixed path. The former would mean a directory in /usr/bin, so
# install to the latter -- it is exactly the packaging case it exists for.
install -D -m 0644 builtin/builtin.odin    "$OUTPUT_DIR/usr/share/ols/builtin/builtin.odin"
install -D -m 0644 builtin/intrinsics.odin "$OUTPUT_DIR/usr/share/ols/builtin/intrinsics.odin"
install -D -m 0644 LICENSE                 "$OUTPUT_DIR/usr/share/ols/LICENSE"
