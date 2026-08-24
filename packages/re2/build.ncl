# Imported from Wolfi `re2` by `pkgmgr import-wolfi` (cmake build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let abseil-cpp = import "../abseil-cpp/build.ncl" in
let icu = import "../icu/build.ncl" in
let gcc = import "../gcc/build.ncl" in
# re2 is date-versioned; upstream git tags are dash-form (2025-11-05). Use the
# dash form so supply-chain's version comparator (splits on `.`) treats a later
# same-year release as newer, and so url/strip_prefix stay coupled to `version`.
let version = "2025-11-05" in
{
  name = "re2",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
    glibc,
    abseil-cpp,
    icu,
    gcc,
    {
      url = "gs://minimal-staging-archives/google/re2/%{version}.tar.gz",
      sha256 = "87f6029d2f6de8aa023654240a03ada90e876ce9a4676e258dd01ea4c26ffd67",
      extract = true,
      strip_prefix = "re2-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc", "libstdcpp"], abseil-cpp, icu],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "google", repo = "re2" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,

  tests = {
    compile_link =
      {
        class = 'Standalone,
        # re2 links abseil + icu, so the compile-link test needs them (+ pkgconf).
        test_deps = [base, toolchain, pkgconf, abseil-cpp, icu],
        cmds = [
          [
            "/bin/bash",
            "-c",
            "cat > t.cpp <<'EOF'\n#include <re2/re2.h>\n#include <string>\n#include <cstdio>\nint main() {\n  std::string s;\n  if (!RE2::FullMatch(\"12345\", \"[0-9]+\")) return 1;\n  if (!RE2::PartialMatch(\"key=value\", \"key=(.*)\", &s) || s != \"value\") return 1;\n  printf(\"ok\\n\");\n  return 0;\n}\nEOF\ng++ $(pkg-config --cflags re2) t.cpp -o t $(pkg-config --libs re2)\n./t | grep -q '^ok$'",
          ],
        ],
      } | Test,
  },
} | BuildSpec
