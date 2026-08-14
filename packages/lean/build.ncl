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

let version = "4.33.0" in
{
  name = "lean",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/leanprover/lean4/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "348d0839049a7cbb72b5e82196670e4ded6e1f8ec4610cd6c5188b2754a1f24c",
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

  needs =
    {
      dns = {},
      internet = {},
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
    # The MODULE ROOTS — `Init.olean`, `Std.olean`, `Lean.olean`, `Lake.olean`
    # — sit directly in `usr/lib/lean/`, and `**/` requires at least one
    # directory level, so the glob above matches `.../Init/Core.olean` but
    # never `.../Init.olean`. Those roots are exactly what `import Init`
    # resolves, so without them lean cannot compile ANY file, including
    # `#eval 1+1`:
    #
    #   error: object file '/usr/lib/lean/Init.olean' of module Init does
    #   not exist
    #
    # Everything else looked right, which is what made it hard to see: 586
    # oleans ship under Init/ and Std/, and the root-level `.a`/`.so` arrive
    # via the `libs` glob above — the only absent class is the one file per
    # module that makes the rest reachable.
    module_roots = { glob = "usr/lib/lean/*.olean" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover",
        repo = "lean4",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
