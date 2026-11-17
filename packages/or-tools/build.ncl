let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# Dependencies or-tools used to build and install its own copy of. Its copies
# landed at the same paths as these packages' files with different contents
# (boost 1,309 files, abseil-cpp 480, protobuf 209, re2 5, zlib 4, bzip2 2:
# amd64 file lists of pkgs b8911794), so or-tools and any of them could not
# share a box under the registry spec's conflict rule (gominimal/arch#183).
let abseil-cpp = import "../abseil-cpp/build.ncl" in
let boost = import "../boost/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let protobuf = import "../protobuf/build.ncl" in
let re2 = import "../re2/build.ncl" in

let version = "9.15" in
{
  name = "or-tools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/or-tools/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6395a00a97ff30af878ee8d7fd5ad0ab1c7844f7219182c6d71acbee1b5f3026",
      extract = true,
      strip_prefix = "or-tools-%{version}",
    } | Source,
    # or-tools' cmake/dependencies FetchContent-clones Eigen 3.4.0 from
    # gitlab.com at build time; GitLab overload ("unable to handle this request
    # due to load") failed the build repeatedly on 2026-10-28. Fetched once,
    # sha256-pinned and mirrored instead; build.sh hands it to FetchContent via
    # FETCHCONTENT_SOURCE_DIR_EIGEN3 and applies or-tools' own patch (pkgs#1146).
    # BZip2 came the same way until it became the bzip2 package below.
    # Eigen 3.4.0 = gitlab.com/libeigen/eigen/-/archive/3.4.0.
    {
      url = "gs://minimal-staging-archives/libeigen/eigen/eigen-3.4.0.tar.gz",
      sha256 = "8586084f71f9bde545ee7fa6d00288b264a2b7ac3607b974e54d13e7162c1c72",
      extract = false,
    } | Source,
    base,
    cmake,
    git,
    make,
    ninja,
    toolchain,
    zlib,
    # The registry's own packages, in place of or-tools' copies (build.sh:
    # BUILD_DEPS=OFF). boost is for soplex (multiprecision, serialization).
    abseil-cpp,
    boost,
    bzip2,
    protobuf,
    re2,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp", "libgomp"],
    zlib,
    abseil-cpp,
    subsetOf boost ["libs"],
    bzip2,
    protobuf,
    re2,
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
    fzn_cp_sat = { glob = "usr/bin/fzn-cp-sat" } | OutputBin,
    highs = { glob = "usr/bin/highs" } | OutputBin,
    sat_runner = { glob = "usr/bin/sat_runner" } | OutputBin,
    scip = { glob = "usr/bin/scip" } | OutputBin,
    solve = { glob = "usr/bin/solve" } | OutputBin,
    vector_bin_packing = { glob = "usr/bin/vector_bin_packing" } | OutputBin,
    libortools = { glob = "usr/lib/libortools*.so*" } | OutputLib,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "google",
        repo = "or-tools",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/usr/bin/bash", "-c", "/usr/bin/fzn-cp-sat --help >/dev/null 2>&1; rc=$?; [ $rc -lt 126 ]"]],
      } | Test,
  },
} | BuildSpec
