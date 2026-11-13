let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let binaryen = import "../binaryen/build.ncl" in
let llvm-23 = import "../llvm-23/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let python = import "../python/build.ncl" in

let glibc = import "../glibc/build.ncl" in

# Emscripten does not support stable LLVM releases in general -- it tracks
# LLVM top-of-tree -- so the version is pinned to the last release whose
# EXPECTED_LLVM_VERSION is 23 (6.0.3; 6.0.4 moved to 24), and it takes LLVM from
# the prefixed llvm-23 (/usr/lib/llvm-23; build.sh points LLVM_ROOT there) rather
# than the default llvm, so a later default major cannot silently change the
# compiler under it. Bumping emscripten means moving it to the llvm-<N> line it
# expects; tools/shared.py holds the expected major, and build.sh fails the
# build when the two disagree. tools/building.py's EXPECTED_BINARYEN_VERSION
# (129 at 6.0.3) is a warning-only check; binaryen here is newer.
#
# LIMITATION -- no JavaScript optimizer. This package ships without the npm
# dependencies emscripten's own installer would fetch (see build.sh), so the
# JS-side toolchain is absent: `acorn`, which tools/acorn-optimizer.mjs drives
# at -O2 and above, and the closure compiler, which is a prebuilt jar. Emitting
# JavaScript works -- `emcc foo.c -o foo.js` is covered by link_run -- but
# `-O2`/`-O3`/`--closure 1` on a link that produces .js will fail resolving
# those modules. Compiling and archiving, which is what vendor:raylib's wasm
# libraries need, is unaffected. Restoring it means vendoring or mirroring the
# npm tree rather than stubbing the install.
let version = "6.0.3" in
{
  name = "emscripten",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/emscripten-core/emscripten/archive/refs/tags/%{version}.tar.gz",
      sha256 = "033241f96a5c50993b43d8383c3356d2804932f5b3548e94c9839c4f68e8b5bd",
      extract = true,
      strip_prefix = "emscripten-%{version}",
    } | Source,
    base,
  ],

  # Emscripten ships no compiled binaries of its own: it is Python and JS
  # driving clang, wasm-ld and binaryen, so everything it calls is a runtime
  # dependency rather than a build one.
  runtime_deps = [
    binaryen,
    glibc,
    subsetOf node-lts ["node"],
    python,
    # bins = clang, wasm-ld, llvm-ar & co.; libs = libLLVM, libclang-cpp, liblld and
    # clang's resource dir, which those binaries load through their $ORIGIN/../lib RPATH.
    subsetOf llvm-23 ["bins", "libs"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/em*" } | OutputBin,
    emscripten = { glob = "usr/share/emscripten/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT AND NCSA",
      source_provenance = {
        category = 'GithubRepo,
        owner = "emscripten-core",
        repo = "emscripten",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["/bin/emcc", "--version"]],
      } | Test,

    # install.py copies the source tree wholesale, which by then also contains
    # whatever the sandbox dropped in beside it -- our own build.sh included.
    # Assert it stays out rather than trusting a local install to be current.
    no_build_scaffolding =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, findutils],
        cmds = [
          ["/bin/bash", "-c", "test ! -e /usr/share/emscripten/build.sh"],
          ["/bin/bash", "-c", "test ! -e /usr/share/emscripten/output"],
          ["/bin/bash", "-c", "test -z \"$(find /usr/share/emscripten -maxdepth 1 -name 'repro_*')\""],
        ],
      } | Test,

    # This package fetches nothing but its own source tarball, and the two
    # things that used to reach the network leave evidence when they run:
    # `npm ci` creates node_modules, and a built port lands in cache/ports.
    # Either reappearing means the build started downloading again -- and since
    # the spec no longer declares dns/internet, it would fail late and obscurely
    # rather than here.
    fetches_nothing =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "test ! -e /usr/share/emscripten/node_modules"],
          ["/bin/bash", "-c", "test ! -e /usr/share/emscripten/cache/ports"],
        ],
      } | Test,

    # Compiles and archives, which is the path a C library build takes. Also
    # proves the prebuilt sysroot cache is complete: with a read-only install
    # emcc cannot build its own libc on first use.
    compile_archive =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint answer(void){ return 42; }\\n' > a.c"],
          ["/bin/bash", "-c", "emcc -c a.c -o a.o && emar rcs liba.a a.o"],
          ["/bin/bash", "-c", "test -s liba.a"],
        ],
      } | Test,

    # Full link through wasm-ld plus binaryen, run under node.
    link_run =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint main(void){ printf(\"ok\\\\n\"); return 0; }\\n' > m.c"],
          # No EM_CACHE set: this also covers the wrapper seeding a writable
          # cache, without which linking against the read-only install fails.
          ["/bin/bash", "-c", "emcc m.c -o m.js"],
          ["/bin/bash", "-c", "test -f m.js && test -f m.wasm"],
          ["/bin/bash", "-c", "node m.js > out.txt 2>&1"],
          ["/bin/bash", "-c", "grep -q ok out.txt"],
        ],
      } | Test,
  },
} | BuildSpec
