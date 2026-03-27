let { subsetOf, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.7.0" in
{
  name = "jsongrep",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/micahkepe/jsongrep/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2db5efbe33cdaba5b93d8a884baa12049b17174d839dce25480551a5fb358375",
      extract = true,
      strip_prefix = "jsongrep-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/jg" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "micahkepe",
      repo = "jsongrep",
    },
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["jg", "--version"]],
      } | Test,
    query_syntax =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # setup test data
          ["/bin/bash", "-c", "echo '{\"name\":\"Alice\",\"address\":{\"city\":\"Seattle\",\"zip\":\"98101\"},\"scores\":[90,85,95]}' > data.json"],
          # field access
          ["/bin/bash", "-c", "jg 'name' --no-path data.json | grep -q '\"Alice\"'"],
          # nested field access
          ["/bin/bash", "-c", "jg 'address.city' --no-path data.json | grep -q '\"Seattle\"'"],
          # array indexing
          ["/bin/bash", "-c", "jg 'scores[0]' --no-path data.json | grep -q '^90$'"],
          # recursive descent with **
          ["/bin/bash", "-c", "echo '{\"a\":{\"name\":\"deep\"},\"name\":\"top\"}' | jg '**.name' --no-path | grep -q '\"deep\"'"],
          # wildcard
          ["/bin/bash", "-c", "echo '{\"x\":1,\"y\":2,\"z\":3}' | jg '*' --no-path --compact | wc -l | grep -q '^3$'"],
          # --count flag
          ["/bin/bash", "-c", "echo '{\"a\":{\"v\":1},\"b\":{\"v\":2}}' | jg '**.v' --count 2>&1 | grep -q 'Found matches: 2'"],
        ],
      } | Test,
  },
} | BuildSpec
