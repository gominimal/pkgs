let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "4.16.0" in
{
  name = "z3-4.16.0",
  # A versioned z3 for tools that pin one: Verus checks for exactly 4.16.0
  # (source/cargo-verus-toolchains/src/external_deps.rs, Z3_VERSION). The
  # binary is /usr/bin/z3-4.16.0, so it coexists with the `z3` package.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Z3Prover/z3/archive/refs/tags/z3-%{version}.tar.gz",
      sha256 = "c68c3e5e4810b16126b8cb4c47eee85c1ac3e24a81914c8e371b40de9dd33ac7",
      extract = true,
      strip_prefix = "z3-z3-%{version}",
    } | Source,
    base,
    cmake,
    ninja,
    # z3's CMake generates sources with python scripts.
    python,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    z3 = { glob = "usr/bin/z3-%{version}" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Z3Prover",
        repo = "z3",
      },
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "z3-%{version} --version | grep -q 'Z3 version %{version}'"],
          ["/bin/bash", "-c", "printf '(declare-const x Int)\\n(assert (> x 2))\\n(check-sat)\\n' | z3-%{version} -in | grep -qx sat"],
          ["/bin/bash", "-c", "printf '(declare-const x Int)\\n(assert (and (> x 2) (< x 1)))\\n(check-sat)\\n' | z3-%{version} -in | grep -qx unsat"],
        ],
      } | Test,
  },
} | BuildSpec
