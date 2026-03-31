let { subsetOf, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.17.0" in
{
  name = "gtest",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/googletest/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c",
      extract = true,
      strip_prefix = "googletest-%{version}",
    } | Source,
    base,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    libgtest = { glob = "usr/lib/libgtest.so*" } | OutputLib,
    libgtest_main = { glob = "usr/lib/libgtest_main.so*" } | OutputLib,
    libgmock = { glob = "usr/lib/libgmock.so*" } | OutputLib,
    libgmock_main = { glob = "usr/lib/libgmock_main.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "google",
      repo = "googletest",
    },
  },
  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <gtest/gtest.h>\nTEST(Smoke, Passes) { EXPECT_EQ(1, 1); }\nint main(int argc, char **argv) { testing::InitGoogleTest(&argc, argv); return RUN_ALL_TESTS(); }' > test.cpp"],
          ["/bin/g++", "test.cpp", "-lgtest", "-o", "test"],
          ["./test"],
        ],
      } | Test,
  },
} | BuildSpec
