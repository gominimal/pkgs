let { BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bison = import "../bison/build.ncl" in
let flex = import "../flex/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let readline = import "../readline/build.ncl" in

let version = "46" in
{
  name = "ngspice",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ngspice-%{version}.tar.gz",
      sha256 = "a0d1699af1940b06649276dcd6ff5a566c8c0cad01b2f7b5e99dedbb4d64c19b",
      extract = true,
      strip_prefix = "ngspice-%{version}",
    } | Source,
    base,
    bison,
    flex,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    ncurses,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    ngspice = { glob = "usr/bin/ngspice" } | OutputBin,
    codemodels = { glob = "usr/lib/ngspice/*.cm", allow_executable = true } | OutputData,
    scripts = { glob = "usr/share/ngspice/scripts/**" } | OutputData,
    man = { glob = "usr/share/man/**/*" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "ngspice",
      repo = "ngspice",
    },
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/bash", "-c", "ngspice -v 2>&1 | grep -q ngspice"]],
      } | Test,
    rc_transient =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > rc_test.cir << 'NETLIST'
          RC Transient Test
          V1 in 0 PWL(0 0 1n 1)
          R1 in out 1k
          C1 out 0 1n
          .tran 10n 5u
          .control
          run
          wrdata rc_out.txt v(out)
          quit
          .endc
          .end
          NETLIST
          ngspice -b rc_test.cir
          test -s rc_out.txt
          # After 5 time constants (tau=RC=1us), cap voltage should be ~0.993V
          tail -1 rc_out.txt | awk '{if ($2 > 0.99) exit 0; else exit 1}'
        "%
          ]
        ],
      } | Test,
  },
} | BuildSpec
