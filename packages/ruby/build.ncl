let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libyaml = import "../libyaml/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "4.0.1" in
{
  name = "ruby",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-%{version}.tar.gz",
      sha256 = "3924be2d05db30f4e35f859bf028be85f4b7dd01714142fd823e4af5de2faf9d",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    rust,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    gdbm,
    gmp,
    libffi,
    libyaml,
    ncurses,
    openssl,
    readline,
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libruby*.so*" } | OutputLib,
    ruby_data = { glob = "usr/lib/ruby/**", allow_executable = true } | OutputData,
    includes = { glob = "usr/include/ruby*/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "ruby",
        repo = "ruby",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        cmds = [
          ["/usr/bin/ruby", "--version"],
        ],
      } | Test,

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "ruby -e 'puts 1+1' | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
