# gungraun-runner: the binary half of Gungraun (formerly iai-callgrind), the
# Rust benchmark harness that measures benchmarks under Valgrind's Callgrind
# (and Cachegrind, DHAT, ...). A project's benches depend on the `gungraun`
# LIBRARY crate; its `main!` harness execs `gungraun-runner` from PATH (or
# GUNGRAUN_RUNNER) and the two must be the SAME VERSION -- the library refuses
# a runner whose version differs. So this package tracks the latest release,
# and a project using it should depend on `gungraun = "=<this version>"`.
#
# Ships no toolchain: the runner is driven by `cargo bench` and calls the
# `cargo` on PATH (cargo metadata), so rust is the user's, as for cargo-mutants.
# valgrind is a runtime dep: the runner execs it for every measurement.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let detbuild = import "../detbuild/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let valgrind = import "../valgrind/build.ncl" in

let version = "0.20.0" in
{
  name = "gungraun-runner",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # The published crate, not the GitHub tag archive: only the .crate carries
      # the Cargo.lock it was released with. sha256 = the crates.io index checksum.
      url = "https://static.crates.io/crates/gungraun-runner/gungraun-runner-%{version}.crate",
      sha256 = "1e1460377fe936c3efbe8e27c422b745fa54ebaea81ffe4a53a6f17c7a478683",
      # a .crate is a gzipped tar; build.sh unpacks it (Source extraction keys on the extension)
      extract = false,
    } | Source,
    {
      # The gungraun LIBRARY at the same version, used only by build.sh's
      # self-test benchmark (nothing from it is installed). Its published
      # Cargo.lock pins the self-test's dependency tree.
      url = "https://static.crates.io/crates/gungraun/gungraun-%{version}.crate",
      sha256 = "c041375e48b8ef7cd2d0e70715598154af627c1a551e41c35fdb4a2b3910831a",
      extract = false,
    } | Source,
    base,
    rust,
    toolchain,
    # Deterministic getrandom/getentropy for the offline build (see build.sh).
    detbuild,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
    valgrind,
  ],

  # cargo fetch (see build.sh)
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    gungraun-runner = { glob = "usr/bin/gungraun-runner" } | OutputBin,
  },

  # A real benchmark (Callgrind, then Cachegrind) runs at the end of build.sh,
  # because building one needs the gungraun library's crates and only the build
  # may fetch. These standalone tests cover what a user's closure provides.
  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/gungraun-runner --version | grep -qw '%{version}'"],
          ["/bin/bash", "-c", "/usr/bin/gungraun-runner --help | grep -q -- '--default-tool'"],
        ],
      } | Test,
    # The runner execs `valgrind` from PATH; it must come with the package.
    valgrind_in_closure =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "valgrind --version | grep -q '^valgrind-' && valgrind --tool=callgrind --help | grep -q -- '--dump-instr'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 OR MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "gungraun",
        repo = "gungraun",
      },
    } | Attrs,
} | BuildSpec
