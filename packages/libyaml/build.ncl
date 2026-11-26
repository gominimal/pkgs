let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.7" in
{
  name = "libyaml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/yaml/libyaml/archive/refs/tags/%{version}.tar.gz",
      sha256 = "7f76964485c67dc4e1537fdfd4ad5c8772bcef501c5451b617e43f831034994e",
      extract = true,
      strip_prefix = "libyaml-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libyaml*.so*" } | OutputLib,
    includes = { glob = "usr/include/yaml.h" } | OutputData,
    cmake_data = { glob = "usr/cmake/yaml*.cmake" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "libyaml",
      source_provenance = {
        category = 'GithubRepo,
        owner = "yaml",
        repo = "libyaml",
      },
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <yaml.h>\n#include <stdio.h>\nint main() { printf(\"%s\\n\", yaml_get_version_string()); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lyaml", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^0\\.'"],
        ],
      } | Test,
  },
} | BuildSpec
