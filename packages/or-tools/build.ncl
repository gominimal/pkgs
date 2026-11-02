let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

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
    # or-tools' cmake/dependencies FetchContent-clones Eigen 3.4.0 and BZip2 from
    # gitlab.com at build time; GitLab overload ("unable to handle this request
    # due to load") failed the build repeatedly on 2026-10-28, and BZip2 was
    # pinned only to `GIT_TAG "master"`. Fetched once, sha256-pinned and
    # mirrored instead; build.sh hands them to FetchContent via
    # FETCHCONTENT_SOURCE_DIR_* and applies or-tools' own patches (pkgs#1146).
    # Eigen 3.4.0 = gitlab.com/libeigen/eigen/-/archive/3.4.0.
    {
      url = "gs://minimal-staging-archives/libeigen/eigen/eigen-3.4.0.tar.gz",
      sha256 = "8586084f71f9bde545ee7fa6d00288b264a2b7ac3607b974e54d13e7162c1c72",
      extract = false,
    } | Source,
    # BZip2 master as of 2026-10-28 (commit 66c46b8c9436613fd81bc5d03f63a61933a4dcc3; or-tools tracks `master`
    # because bzip2-1.0.8 has no CMake support).
    {
      url = "gs://minimal-staging-archives/bzip2/bzip2/bzip2-66c46b8c9436613fd81bc5d03f63a61933a4dcc3.tar.gz",
      sha256 = "3a4cff5f9d197e9e6c6138660afa6b1f9370df0bed135bd949243f6dfc83b3e1",
      extract = false,
    } | Source,
    base,
    cmake,
    git,
    make,
    ninja,
    toolchain,
    zlib,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
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
    bins = { glob = "usr/bin/*" } | OutputBin,
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
} | BuildSpec
