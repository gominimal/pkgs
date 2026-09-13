let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let cadical = import "../cadical/build.ncl" in

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
    # `bv_decide` shells out to the `cadical` SAT solver by name on PATH. An
    # official Lean release bundles it in `bin/`; built from source we don't
    # get one, and `bv_decide` fails with "could not execute external process
    # 'cadical'" (found building aeneas-latest). Same release Lean pins.
    cadical,
    # `lean` and `libleanshared.so` link libssl.so.3 / libcrypto.so.3 (lake's
    # HTTP client). Without this the binary does not START in a closure that
    # lacks openssl — `lean --version` exits 127 from the loader — which the
    # standalone test below now catches. Every session that had run lean so
    # far carried openssl through some other package, which is how it hid.
    openssl,
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
    # `*.olean*`: Lean >= 4.2x ships every module as `.olean` +
    # `.olean.server` + `.olean.private`, and lean will not load a module whose
    # sidecars are missing. The plain `*.olean` glob silently dropped the other
    # two at packaging, so pkgs#605's root fix was necessary but not sufficient.
    # `.ilean` is the language-server index (small; makes `lean --server` work).
    data = { glob = "usr/lib/lean/**/*.olean*" } | OutputData,
    ilean = { glob = "usr/lib/lean/**/*.ilean" } | OutputData,
    # Compiled IR per module (`X.ir` + `X.ir.sig`). `lean` alone runs without
    # them; `lake` cannot configure a project without them (see build.sh).
    ir = { glob = "usr/lib/lean/**/*.ir" } | OutputData,
    ir_sig = { glob = "usr/lib/lean/**/*.ir.sig" } | OutputData,
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
    module_roots = { glob = "usr/lib/lean/*.olean*" } | OutputData,
    module_root_ileans = { glob = "usr/lib/lean/*.ilean" } | OutputData,
    module_root_irs = { glob = "usr/lib/lean/*.ir" } | OutputData,
    module_root_ir_sigs = { glob = "usr/lib/lean/*.ir.sig" } | OutputData,
  },

  # The check that has now failed twice for two different missing-file
  # classes (pkgs#605: no roots; this PR: no sidecars). If lean cannot
  # compile `#eval 1+1`, it cannot compile anything, and no other output of
  # this package matters.
  tests = {
    compiles_hello =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf '#eval 1+1\\n' > /tmp/t.lean && lean /tmp/t.lean"],
          ["/bin/bash", "-c", "printf 'theorem t : 1 + 1 = 2 := rfl\\n' > /tmp/u.lean && lean /tmp/u.lean"],
          # `lake` must be able to configure and build a project: this is what
          # the missing `.ir` files broke while `lean` itself still worked.
          ["/bin/bash", "-c", "mkdir -p /tmp/lk && cd /tmp/lk && printf 'import Lake\\nopen Lake DSL\\npackage t\\n@[default_target] lean_lib T\\n' > lakefile.lean && mkdir -p T && printf 'def hello := 42\\n' > T.lean && LAKE_NO_CACHE=1 HOME=/tmp/lk lake build"],
        ],
      } | Test,
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
