# Imported from Wolfi `jsoncpp` by `pkgmgr import-wolfi` (cmake build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "1.9.8" in
{
  name = "jsoncpp",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
    glibc,
    gcc,
    {
      url = "gs://minimal-staging-archives/open-source-parsers/jsoncpp/%{version}.tar.gz",
      sha256 = "51828cf3574281d2b79ec2a1c56a9e4c20cc1103711321ea96384cffb8d2d904",
      extract = true,
      strip_prefix = "jsoncpp-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc", "libstdcpp"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "open-source-parsers", repo = "jsoncpp" },
      license_spdx = "CC-PDDC OR MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "set -euo pipefail\n\ntee test_jsoncpp.cpp <<'EOF'\n#include <json/json.h>\n#include <iostream>\nint main() {\n    const std::string rawJson = R\"({\"name\": \"John\", \"age\": 30, \"city\": \"New York\"})\";\n    Json::CharReaderBuilder builder;\n    Json::CharReader* reader = builder.newCharReader();\n    Json::Value root;\n    std::string errors;\n    bool parsingSuccessful = reader->parse(rawJson.c_str(), rawJson.c_str() + rawJson.size(), &root, &errors);\n    delete reader;\n    if (!parsingSuccessful) {\n        std::cerr << \"Failed to parse the JSON string: \" << errors << std::endl;\n        return 1;\n    }\n    std::string name = root[\"name\"].asString();\n    int age = root[\"age\"].asInt();\n    std::string city = root[\"city\"].asString();\n    if (name == \"John\" && age == 30 && city == \"New York\") {\n        std::cout << \"JSON parsing succeeded!\" << std::endl;\n        return 0;\n    } else {\n        std::cerr << \"JSON parsing failed!\" << std::endl;\n        return 1;\n    }\n}\nEOF\n\ng++ test_jsoncpp.cpp -o test_jsoncpp -ljsoncpp\n./test_jsoncpp"],
        ],
      } | Test,
  },
} | BuildSpec
