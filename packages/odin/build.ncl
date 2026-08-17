let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libglvnd = import "../libglvnd/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let lua51 = import "../lua51/build.ncl" in
let lua52 = import "../lua52/build.ncl" in
let lua53 = import "../lua53/build.ncl" in
let lua54 = import "../lua54/build.ncl" in
let make = import "../make/build.ncl" in
let raygui = import "../raygui/build.ncl" in
let raylib = import "../raylib/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "dev-2026-07a" in
# Odin stamps its own `ODIN_VERSION` from the month of the release commit.
# Pinned here so the build does not read the wall clock (see build.sh).
let version_date = "2026-07" in
# Matches the version upstream's vendor/box2d/build_box2d.sh pins.
let box2d_version = "3.1.1" in
{
  name = "odin",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/odin-lang/Odin/archive/refs/tags/%{version}.tar.gz",
      sha256 = "8f4f02fd9a3426b441cd0dfbe0aca1b95fd93c95d86940fcb4417ef6044c83cd",
      extract = true,
      strip_prefix = "Odin-%{version}",
    } | Source,
    # vendor/box2d carries bindings but no Linux library, and no C source to
    # build one from -- upstream's build_box2d.sh downloads this same tarball.
    {
      url = "https://github.com/erincatto/box2d/archive/refs/tags/v%{box2d_version}.tar.gz",
      sha256 = "fb6ef914b50f4312d7d921a600eabc12318bb3c55a0b8c0b90608fa4488ef2e4",
      extract = true,
    } | Source,
    base,
    cmake, # box2d
    llvm,
    make, # vendor/{stb,cgltf}/src ship Makefiles we build the bindings' C libs with
    # vendor/raylib carries bindings and checked-in binaries but no C source at
    # all, so unlike the other vendor libraries there is nothing to compile in
    # place -- the libraries come from these packages instead.
    raygui,
    raylib,
    toolchain,
  ],

  runtime_deps = [
    # `odin build` shells out to `clang` to link every program it compiles, and
    # clang in turn needs binutils' `ld` plus gcc's crt objects and libgcc — so
    # the whole C toolchain is needed wherever odin runs, not just to build it.
    toolchain,
    # libllvm: the compiler itself links against the shared libLLVM.
    # bins/libs_clang: the `clang` driver above, and `ld.lld` for `-linker:lld`.
    subsetOf llvm ["bins", "libllvm", "libs_clang", "liblld", "libclang"],
    # vendor:lua links the bundled library only on Linux/amd64; every other
    # target falls back to `system:lua<ver>`, which needs liblua5.N.so present
    # wherever odin runs. Runtime rather than build deps so that fallback
    # resolves -- and since runtime_deps are injected into the build too, this
    # is also what supplies the libraries copied into the vendor tree on amd64.
    lua51,
    lua52,
    lua53,
    lua54,
    # vendor:raylib's bindings declare `system:X11`, and the static libraylib.a
    # we ship pulls in libGL, so `odin build` on anything importing it needs
    # both present -- the same reasoning as the lua fallback above. Only the
    # `libs` output of each: the headers and pkgconfig files are build-time
    # concerns, and taking libglvnd whole would drag mesa's drivers in behind it
    # for a linkage that only needs libGL.so.1.
    subsetOf libglvnd ["libs"],
    subsetOf libx11 ["libs"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include version_date,
    include box2d_version,
  },

  outputs = {
    # Symlink into the collection tree below: `odin` finds its ODIN_ROOT by
    # reading /proc/self/exe, which resolves symlinks.
    odin = { glob = "usr/bin/odin" } | OutputBin,
    odin_bin = { glob = "usr/lib/odin/odin" } | OutputBin,

    base_collection = { glob = "usr/lib/odin/base/**" } | OutputData,
    core_collection = { glob = "usr/lib/odin/core/**" } | OutputData,
    # vendor ships prebuilt static/shared libraries for the bindings it wraps.
    vendor_collection = { glob = "usr/lib/odin/vendor/**", allow_executable = true } | OutputData,
    examples = { glob = "usr/lib/odin/examples/**" } | OutputData,
    license = { glob = "usr/lib/odin/LICENSE" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "odin-lang",
        repo = "Odin",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/odin version",

    compile_run =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "printf 'package main\\nimport \"core:fmt\"\\nmain :: proc() { fmt.println(\"ok\") }\\n' > hellope.odin"],
          ["/bin/odin", "run", "hellope.odin", "-file"],
        ],
      } | Test,

    # Links against the vendor C libraries this package builds from source.
    # Upstream ships no Linux build of stb or cgltf, so against upstream's own
    # tree this fails at compile time with "Could not find the compiled STB
    # libraries" -- it guards the vendor build, not just the bindings.
    vendor_link =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "printf 'package main\\nimport stbi \"vendor:stb/image\"\\nimport \"vendor:cgltf\"\\nimport b3 \"vendor:box3d\"\\nimport b2 \"vendor:box2d\"\\nmain :: proc() {\\n_ = stbi.failure_reason()\\ncgltf.free(nil)\\n_ = b3.GetVersion()\\n_ = b2.GetByteCount()\\n}\\n' > vendor.odin"],
          ["/bin/odin", "build", "vendor.odin", "-file"],
        ],
      } | Test,

    # vendor:raylib is the one binding whose link needs libraries from outside
    # the vendor tree (system:X11 plus libGL, via the static archive), so it is
    # the only one that can regress on runtime_deps alone. vendor_link covers
    # stb/cgltf/box2d/box3d, which link nothing external; without this, dropping
    # the X11/GL entries above would break every raylib user silently. Links but
    # does not run -- there is no display in the sandbox.
    vendor_link_raylib =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "printf 'package main\\nimport rl \"vendor:raylib\"\\nmain :: proc() { _ = rl.GetRandomValue(1, 1) }\\n' > rl.odin"],
          ["/bin/odin", "build", "rl.odin", "-file"],
        ],
      } | Test,

    # Existence checks cannot tell our libraries from upstream's, since both
    # land at the same paths. This compares the vendor copies byte-for-byte
    # against what the source-built packages emit, so reintroducing a checked-in
    # blob fails here instead of shipping.
    vendor_provenance =
      {
        class = 'Standalone,
        test_deps = [base, lua51, lua52, lua53, lua54, raygui, raylib],
        cmds = [
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; case $(uname -m) in x86_64) RL=linux;; *) RL=linux-arm64;; esac; cmp $V/raylib/$RL/libraylib.a /usr/lib/libraylib.a; cmp $V/raylib/$RL/libraylib.so.600 /usr/lib/libraylib.so.6.0.0; cmp $V/raylib/linux/libraygui.a /usr/lib/libraygui.a; cmp $V/raylib/linux/libraygui.so /usr/lib/libraygui.so"],
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; cmp $V/raylib/wasm/libraylib.web.a /usr/lib/emscripten/libraylib.web.a; cmp $V/raylib/wasm/libraygui.a /usr/lib/emscripten/libraygui.a"],
          # lua is bundled on amd64 only; elsewhere the bindings use system:lua.
          ["/bin/bash", "-c", "set -eu; [ $(uname -m) = x86_64 ] || exit 0; V=$(/bin/odin root)/vendor; for s in 5.1:5.1 5.2:52 5.3:53 5.4:54; do a=${s%:*}; b=${s#*:}; cmp $V/lua/$a/linux/liblua$b.a /usr/lib/liblua$a.a; cmp $V/lua/$a/linux/liblua$b.so /usr/lib/liblua$a.so; done"],
        ],
      } | Test,

    # Asserts the shape of the vendor tree: every library we ship is one we built
    # from source, and every artifact we deliberately drop (Windows, macOS, the
    # other Linux arch) is gone. Pins the de-blobbing so a future version bump
    # that reintroduces upstream's prebuilts fails here rather than shipping
    # silently.
    vendor_tree =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Native libraries built from the vendored C source.
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; case $(uname -m) in x86_64) A=linux-amd64; B2=box2d_other_amd64_avx2.a;; *) A=linux-arm64; B2=box2d_other.a;; esac; test -f $V/box3d/lib/$A/libbox3d.a; test -f $V/stb/lib/stb_image.a; test -f $V/cgltf/lib/cgltf.a; test -f $V/box2d/lib/$B2"],

          # raylib and raygui, which upstream ships only as binaries.
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; case $(uname -m) in x86_64) RL=linux; test ! -e $V/raylib/linux-arm64;; *) RL=linux-arm64; test ! -e $V/raylib/linux/libraylib.a;; esac; test -f $V/raylib/$RL/libraylib.a; test -f $V/raylib/$RL/libraylib.so.600; test -f $V/raylib/linux/libraygui.a; test -f $V/raylib/linux/libraygui.so"],

          # Every wasm artifact is rebuilt from source as well -- the objects
          # from plain clang, the two raylib archives through emscripten.
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; test -f $V/box2d/lib/box2d_wasm.o; test -f $V/box2d/lib/box2d_wasm_simd.o; test -f $V/cgltf/lib/cgltf_wasm.o; for o in image image_resize image_write rect_pack sprintf truetype vorbis; do test -f $V/stb/lib/stb_${o}_wasm.o; done; test -f $V/raylib/wasm/libraylib.web.a; test -f $V/raylib/wasm/libraygui.a"],

          # lua only has a bundled library to build on amd64; elsewhere the
          # bindings fall back to system:lua<ver>.
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; if [ $(uname -m) = x86_64 ]; then test -f $V/lua/5.4/linux/liblua54.a; else test ! -e $V/lua/5.4/linux; fi"],

          # Everything we deliberately drop.
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; case $(uname -m) in x86_64) OTHER=linux-arm64;; *) OTHER=linux-amd64;; esac; test ! -e $V/box3d/lib/$OTHER; test ! -e $V/raylib/macos; test -z \"$(find $V -type d -name darwin)\"; test -z \"$(find $V -type f \\( -name '*.dll' -o -name '*.lib' -o -name '*.exe' -o -name '*.pdb' \\))\""],
        ],
      } | Test,
  },
} | BuildSpec
