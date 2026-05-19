let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "4.28.0" in
{
  name = "lean",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/leanprover/lean4/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "b50c5423a72098aedcea9650264d936f2a3d3903daef7f082e7ffc5b7d323974",
    } | Source,
    # cmake submodules that lean's CMakeLists.txt would normally clone via
    # ExternalProject_add(GIT_REPOSITORY ...). Pre-staged here so build.sh
    # can sed-patch them to use SOURCE_DIR instead of cloning. Both URLs
    # are the github release-archive (not /tarball/...) so the extracted
    # directory names are deterministic across re-downloads.
    {
      url = "https://github.com/arminbiere/cadical/archive/refs/tags/rel-2.1.2.tar.gz",
      sha256 = "292c2bb8d712d6d05fce3d3df63b922b8fa45e03974a79f7bae5bf68c284f131",
    } | Source,
    {
      url = "https://github.com/libuv/libuv/archive/refs/tags/v1.48.0.tar.gz",
      sha256 = "8c253adb0f800926a6cbd1c6576abae0bc8eb86a4f891049b72f9e5b7dc58f33",
    } | Source,
    # mimalloc uses the /tarball/<tag> github api endpoint; the release-
    # archive form returns 404 for this repo. Tarball extracts to a
    # sha-prefixed dir (microsoft-mimalloc-<short-sha>/) — deterministic
    # for the same tarball content. build.sh resolves the dir name with
    # a wildcard glob to avoid hardcoding the hash.
    {
      url = "https://api.github.com/repos/microsoft/mimalloc/tarball/v2.2.3",
      sha256 = "4d28e5fcac94089979e4016cf6454ebb4558a87378372cbd982e8a9b7c7ae56b",
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    gmp,
    libuv,
    pkgconf,
    git,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    gmp,
    libuv,
  ],

  # No internet needed: the three GIT_REPOSITORY ExternalProjects in
  # lean's CMakeLists are sed-patched to SOURCE_DIR by build.sh, using
  # the cadical/libuv/mimalloc Source build_deps above.
  needs =
    {
      dns = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    lake = { glob = "usr/bin/lake" } | OutputBin,
    leanchecker = { glob = "usr/bin/leanchecker" } | OutputBin,
    leanmake = { glob = "usr/bin/leanmake", allow_missing_interpreter = true } | OutputBin,
    leanc = { glob = "usr/bin/leanc" } | OutputBin,
    lean = { glob = "usr/bin/lean" } | OutputBin,
    libs = { glob = "usr/lib/lean/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    data = { glob = "usr/lib/lean/**/*.olean" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover",
        repo = "lean4",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
