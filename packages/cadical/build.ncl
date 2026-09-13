let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# The release Lean 4.33 bundles as `bin/cadical` (lean4 CMake INSTALL_CADICAL).
let version = "2.1.2" in
{
  name = "cadical",
  # CaDiCaL, the SAT solver behind Lean's `bv_decide`. Official Lean releases
  # ship it next to `lean`; a from-source lean build does not, and `bv_decide`
  # then fails with "could not execute external process 'cadical'". It is found
  # by name on PATH, so this package is enough.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/arminbiere/cadical/archive/refs/tags/rel-%{version}.tar.gz",
      sha256 = "292c2bb8d712d6d05fce3d3df63b922b8fa45e03974a79f7bae5bf68c284f131",
      extract = true,
      strip_prefix = "cadical-rel-%{version}",
    } | Source,
    base,
    toolchain,
    make,
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
    cadical = { glob = "usr/bin/cadical" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "arminbiere",
        repo = "cadical",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cadical --version"],
          # A two-clause satisfiable formula: exit code 10 is SAT by DIMACS convention.
          ["/bin/bash", "-c", "printf 'p cnf 2 2\\n1 2 0\\n-1 0\\n' > /tmp/f.cnf; cadical -q /tmp/f.cnf; test $? -eq 10"],
        ],
      } | Test,
  },
} | BuildSpec
