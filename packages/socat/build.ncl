let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.8.1.1" in
{
  name = "socat",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "http://www.dest-unreach.org/socat/download/socat-%{version}.tar.gz",
      sha256 = "f68b602c80e94b4b7498d74ec408785536fe33534b39467977a82ab2f7f01ddb",
      extract = true,
      strip_prefix = "socat-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    openssl,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    version_check = {
      class = 'Standalone,
      test_deps = [],
      cmds = [["socat", "-V"]],
    } | Test,
  },
} | BuildSpec
