let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.0.4" in
{
  name = "kissat",
  # Kissat, the SAT solver Kani runs CBMC with by default (`--solver kissat`
  # execs `kissat` off PATH). Kani 0.68.0's kani-dependencies asks for at least
  # 4.0.1; scripts/check_kissat_version.sh is a minimum, not a pin.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/arminbiere/kissat/archive/refs/tags/rel-%{version}.tar.gz",
      sha256 = "bfe93eaa6323b48011e4b1fcf74b3f2e20f9de544767e728009e5b2018296193",
      extract = true,
      strip_prefix = "kissat-rel-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    kissat = { glob = "usr/bin/kissat" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "arminbiere",
        repo = "kissat",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(kissat --version)\" = %{version}"],
          # DIMACS exit codes: 10 is SAT, 20 is UNSAT.
          ["/bin/bash", "-c", "printf 'p cnf 2 2\\n1 2 0\\n-1 0\\n' > /tmp/s.cnf; kissat -q /tmp/s.cnf; test $? -eq 10"],
          ["/bin/bash", "-c", "printf 'p cnf 1 2\\n1 0\\n-1 0\\n' > /tmp/u.cnf; kissat -q /tmp/u.cnf; test $? -eq 20"],
        ],
      } | Test,
  },
} | BuildSpec
