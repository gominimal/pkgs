let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let patch = import "../patch/build.ncl" in
let perl = import "../perl/build.ncl" in
let m4 = import "../m4/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.11.0" in
{
  name = "cbmc",
  # CBMC, the C bounded model checker that Kani drives. Kani 0.68.0's
  # kani-dependencies pins CBMC_VERSION="6.11.0". Built with upstream's
  # release solver set (minisat2 + cadical); Kani adds kissat as an external
  # solver.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/diffblue/cbmc/archive/refs/tags/cbmc-%{version}.tar.gz",
      sha256 = "217e5ed631bbd4b39659fde37a603482003605abd4cb2586b09c2da344d925db",
      extract = true,
      strip_prefix = "cbmc-cbmc-%{version}",
    } | Source,
    # The two solvers CBMC's CMake would otherwise download (see build.sh).
    # Same URLs and checksums as src/solvers/CMakeLists.txt at this tag.
    {
      url = "https://deb.debian.org/debian/pool/main/m/minisat2/minisat2_2.2.1.orig.tar.gz",
      sha256 = "e54afa3c192c1753bc8075c0c7e126d5c495d9066e3f90a2588091149ac9ca40",
      extract = false,
    } | Source,
    {
      url = "https://github.com/arminbiere/cadical/archive/rel-3.0.0.tar.gz",
      sha256 = "282b1c9422fde8631cb721b86450ae94df4e8de0545c17a69a301aaa4bf92fcf",
      extract = false,
    } | Source,
    base,
    toolchain,
    cmake,
    ninja,
    flex,
    bison,
    # flex and bison exec m4 but do not declare it (see the TODO in bison).
    m4,
    patch,
    # src/ansi-c/library_check.sh preprocesses the C library models with perl.
    perl,
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
    bins = { glob = "usr/bin/*" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-4-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "diffblue",
        repo = "cbmc",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        # `cbmc file.c` preprocesses with `gcc -E`. Kani hands CBMC goto
        # binaries, not C, so gcc is not a runtime dep; these C tests need it.
        test_deps = [base, gcc],
        cmds = [
          ["/bin/bash", "-c", "cbmc --version | grep -q '^%{version}'"],
          # An out-of-bounds write CBMC must find: exit 10 is "VERIFICATION FAILED".
          ["/bin/bash", "-c", "printf 'int main(){int a[2]; unsigned i; a[i]=1; return 0;}' > /tmp/oob.c; cbmc --bounds-check /tmp/oob.c >/tmp/oob.out 2>&1; test $? -eq 10 && grep -q 'VERIFICATION FAILED' /tmp/oob.out"],
          # And a safe one it must prove: exit 0, "VERIFICATION SUCCESSFUL".
          ["/bin/bash", "-c", "printf 'int main(){int a[2]; unsigned i; if(i<2) a[i]=1; return 0;}' > /tmp/ok.c; cbmc --bounds-check /tmp/ok.c >/tmp/ok.out 2>&1 && grep -q 'VERIFICATION SUCCESSFUL' /tmp/ok.out"],
          ["/bin/bash", "-c", "goto-cc --version && goto-instrument --version"],
        ],
      } | Test,
  },
} | BuildSpec
