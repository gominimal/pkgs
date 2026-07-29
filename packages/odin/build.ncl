let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "dev-2026-07a" in
# Odin stamps its own `ODIN_VERSION` from the month of the release commit.
# Pinned here so the build does not read the wall clock (see build.sh).
let version_date = "2026-07" in
# Matches the version upstream's vendor/box2d/build_box2d.sh pins.
let box2d_version = "3.1.1" in
# The exact versions vendor/lua/README.md documents, confirmed against the
# version strings in the .so files upstream ships. Kept at these patch levels so
# this is a faithful source-built replacement of those blobs rather than a bump.
let lua51_version = "5.1.5" in
let lua52_version = "5.2.4" in
let lua53_version = "5.3.6" in
let lua54_version = "5.4.2" in
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
    # vendor/lua carries bindings plus prebuilt .a/.so per minor version.
    {
      url = "https://www.lua.org/ftp/lua-%{lua51_version}.tar.gz",
      sha256 = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333",
      extract = true,
    } | Source,
    {
      url = "https://www.lua.org/ftp/lua-%{lua52_version}.tar.gz",
      sha256 = "b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b",
      extract = true,
    } | Source,
    {
      url = "https://www.lua.org/ftp/lua-%{lua53_version}.tar.gz",
      sha256 = "fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60",
      extract = true,
    } | Source,
    {
      url = "https://www.lua.org/ftp/lua-%{lua54_version}.tar.gz",
      sha256 = "11570d97e9d7303c0a59567ed1ac7c648340cd0db10d5fd594c09223ef2f524f",
      extract = true,
    } | Source,
    base,
    cmake, # box2d
    llvm,
    make, # vendor/{stb,cgltf}/src ship Makefiles we build the bindings' C libs with
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
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include version_date,
    include box2d_version,
    include lua51_version,
    include lua52_version,
    include lua53_version,
    include lua54_version,
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

    # Asserts the shape of the vendor tree: every library we build from source is
    # present, and every artifact we deliberately drop (Windows, macOS, the other
    # Linux arch) is gone. Pins the de-blobbing so a future version bump that
    # reintroduces upstream's prebuilts fails here rather than shipping silently.
    vendor_tree =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -eu; V=$(/bin/odin root)/vendor; if [ $(uname -m) = x86_64 ]; then MINE=linux-amd64; OTHER=linux-arm64; RLO=linux-arm64; B2=box2d_other_amd64_avx2.a; test -f $V/lua/5.4/linux/liblua54.a; else MINE=linux-arm64; OTHER=linux-amd64; RLO=linux; B2=box2d_other.a; test ! -e $V/lua/5.4/linux; fi; test -f $V/box3d/lib/$MINE/libbox3d.a; test -f $V/stb/lib/stb_image.a; test -f $V/cgltf/lib/cgltf.a; test -f $V/box2d/lib/$B2; test ! -e $V/box3d/lib/$OTHER; test ! -e $V/raylib/$RLO; test ! -e $V/raylib/macos; test -z \"$(find $V -type d -name darwin)\"; test -z \"$(find $V -type f -name '*.dll' -o -name '*.lib' -o -name '*.exe' -o -name '*.pdb')\""],
        ],
      } | Test,
  },
} | BuildSpec
