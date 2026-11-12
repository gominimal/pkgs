let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let clipper2 = import "../clipper2/build.ncl" in
let onetbb = import "../onetbb/build.ncl" in

let version = "3.5.4" in
{
  name = "manifold",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/elalish/manifold/manifold-%{version}.tar.gz",
      sha256 = "db2a8e7aac6abac12fe54fa7b055d24741362b5706fee6f5c5b8f0bccd2de4ec",
      extract = true,
      strip_prefix = "manifold-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    clipper2,
    onetbb,
  ],

  cmd = "./build.sh",
  outputs = {
    libmanifold = { glob = "usr/lib/libmanifold*.so*" } | OutputLib,

    includes = { glob = "usr/include/manifold/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/manifold/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "manifold-geometry-library",
      source_provenance = {
        category = 'GithubRepo,
        owner = "elalish",
        repo = "manifold",
      },
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
              g++ -x c++ - -o t -x none -std=c++17 -lmanifold <<'EOF'
              #include <cstdio>
              #include <manifold/manifold.h>
              int main() {
                manifold::Manifold a = manifold::Manifold::Cube({2.0, 2.0, 2.0});
                manifold::Manifold b = manifold::Manifold::Cube({1.0, 1.0, 1.0});
                double v = (a - b).Volume();
                std::printf("volume=%f\n", v);
                return !(v > 6.99 && v < 7.01);
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
