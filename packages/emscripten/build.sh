#!/bin/sh
set -ex

EM_ROOT="$OUTPUT_DIR/usr/share/emscripten"

# install.py unconditionally runs `npm ci`, pulling ~110 packages from
# registry.npmjs.org and executing their lifecycle scripts. Those drive the
# JS-side tooling only -- optimising and minifying generated glue -- and nothing
# on the compile-and-archive path this package exists for touches them. Feeding
# it a no-op `npm` on PATH keeps the whole npm registry out of the build.
# The stub lives outside the source tree: install.py copies that tree wholesale,
# so anything left beside it gets shipped.
NPM_STUB=/tmp/npm-stub
mkdir -p "$NPM_STUB"
printf '#!/bin/sh\nexit 0\n' > "$NPM_STUB/npm"
chmod 0755 "$NPM_STUB/npm"

# Emscripten's own packaging entry point: like `make dist`, but it drops the
# test corpus, git metadata and other things end users never need.
PATH="$NPM_STUB:$PATH" python3 tools/install.py "$EM_ROOT"

rm -rf "$NPM_STUB"

# Emscripten looks for a config beside its own root before falling back to
# $HOME, so the packaged config lives inside the install tree and needs no
# environment set up by the caller. LLVM_ROOT is a directory of binaries;
# BINARYEN_ROOT is a prefix with bin/ underneath it.
cat > "$EM_ROOT/.emscripten" <<'EOF'
LLVM_ROOT = '/usr/bin'
BINARYEN_ROOT = '/usr'
NODE_JS = '/usr/bin/node'
EOF

# install.py copies the source tree, which by then also holds whatever the
# sandbox and the build have put beside it: our own build.sh, and $OUTPUT_DIR
# itself -- its EXCLUDES list covers `out`, not `output`. Neither is ours to
# ship. Harmless on a clean build (output is still empty when install.py runs)
# but it is copy-what-is-there, so drop both rather than rely on ordering.
rm -f "$EM_ROOT/build.sh"
rm -rf "$EM_ROOT/output"

# Each entry point is a shell stub that runs "$0.py", so it has to see its own
# path inside the emscripten tree -- a symlink from /usr/bin would send it
# looking for /usr/bin/emcc.py. Hence wrappers rather than links.
mkdir -p "$OUTPUT_DIR/usr/bin"
for t in em++ em-config emar embuilder emcc emcmake emconfigure emdwp emmake \
         emnm emprofile emranlib emrun emscan-deps emscons emsize emstrip \
         emsymbolizer; do
  cat > "$OUTPUT_DIR/usr/bin/$t" <<EOF
#!/bin/sh
# emcc writes to its cache while linking even when every entry is already
# built. Seed a per-user copy on first use so linking works out of the box,
# offline, with the prebuilt sysroot intact. Set EM_CACHE yourself to override.
#
# Keyed on EM_CACHE alone, deliberately: testing the packaged cache for
# writability would say "writable" for root (test -w only checks the mode
# bits, and the directory is 0755), and this package is content-addressed --
# writing into it corrupts the store rather than merely being untidy. It is
# never the right target, whatever the permissions say.
if [ -z "\$EM_CACHE" ]; then
  EM_CACHE="\${XDG_CACHE_HOME:-\${HOME:-/tmp}/.cache}/emscripten-$MINIMAL_ARG_VERSION"
  if [ ! -d "\$EM_CACHE" ]; then
    # Populate a scratch copy and claim it with a single rename, so a
    # concurrent emcc or an interrupted copy can never leave a half-populated
    # sysroot that every later run would reuse. mv -T fails rather than
    # nesting if another process won the race.
    mkdir -p "\$(dirname "\$EM_CACHE")"
    _emtmp=\$(mktemp -d "\$EM_CACHE.tmp.XXXXXX") || exit 1
    cp -a /usr/share/emscripten/cache/. "\$_emtmp"/
    mv -T "\$_emtmp" "\$EM_CACHE" 2>/dev/null || rm -rf "\$_emtmp"
  fi
  export EM_CACHE
fi
exec /usr/share/emscripten/$t "\$@"
EOF
  chmod 0755 "$OUTPUT_DIR/usr/bin/$t"
done

# emcc compiles its own sysroot (musl libc, compiler-rt, libc++) on first use
# and caches it inside the install tree. That tree is read-only once packaged,
# so build the cache here instead of failing at the first invocation.
#
# SYSTEM, not ALL: ALL additionally builds every optional PORT (SDL, ICU,
# harfbuzz, sqlite, ...), and each port is downloaded from its own upstream at
# build time -- ~26 projects across 7 hosts, none of them mirrored. Nothing here
# uses one: raylib's web build is compile-and-archive, and its -sUSE_GLFW=3 is a
# built-in JS library, not a port. A consumer who does want a port can point
# EM_CACHE at a writable directory, which the wrappers above already arrange.
export EM_CACHE="$EM_ROOT/cache"
"$EM_ROOT/embuilder" build SYSTEM

# cache/build holds intermediate objects kept only to rebuild, which a read-only
# install cannot do. Only cache/sysroot is consulted at link time.
rm -rf "$EM_ROOT/cache/build"

find "$EM_ROOT" -name '__pycache__' -type d -prune -exec rm -rf {} +

