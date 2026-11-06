let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "2023.2.0" in
{
  name = "onetbb",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/uxlfoundation/oneTBB/v%{version}.tar.gz",
      sha256 = "80cb62e62defeee67ea1885a6f72d97ac81404f8fde9cded62fb51524808a30c",
      extract = true,
      strip_prefix = "oneTBB-%{version}",
    } | Source,
    base,
    make,
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
    libtbb = { glob = "usr/lib/libtbb*.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/TBB/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "onetbb",
      source_provenance = {
        category = 'GithubRepo,
        owner = "uxlfoundation",
        repo = "oneTBB",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              cd /tmp
              g++ -x c++ - -o t -x none -ltbb <<'EOF'
              #include <cstdio>
              #include <oneapi/tbb/parallel_reduce.h>
              #include <oneapi/tbb/blocked_range.h>
              #include <oneapi/tbb/version.h>
              int main() {
                long s = oneapi::tbb::parallel_reduce(
                    oneapi::tbb::blocked_range<long>(1, 1001), 0L,
                    [](const oneapi::tbb::blocked_range<long> &r, long acc) {
                      for (long i = r.begin(); i != r.end(); ++i) acc += i;
                      return acc;
                    },
                    [](long a, long b) { return a + b; });
                std::printf("tbb %s sum=%ld\n", TBB_runtime_version(), s);
                return s != 500500;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
