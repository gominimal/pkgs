let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.8.1" in
{
  name = "jq",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/jq-%{version}.tar.gz",
      sha256 = "2be64e7129cecb11d5906290eba10af694fb9e3e7f9fc208a311dc33ca837eb0",
      extract = true,
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    jq = { glob = "usr/bin/jq" } | OutputBin,

    libjq = { glob = "usr/lib/libjq.{so*,a}" } | OutputLib,
    libonig = { glob = "usr/lib/libonig.{so*,a}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "jq",
      source_provenance = {
        category = 'GithubRepo,
        owner = "jqlang",
        repo = "jq",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/jq --version",

    basic =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '{\"name\":\"Alice\",\"age\":30}' > data.json"],
          ["/bin/bash", "-c", "jq '.name' data.json | grep -q '\"Alice\"'"], # extract field
          ["/bin/bash", "-c", "jq '.age' data.json | grep -q '^30$'"], # extract number
          ["/bin/bash", "-c", "echo '[1,2,3,4,5]' > array.json"],
          ["/bin/bash", "-c", "jq '.[2]' array.json | grep -q '^3$'"], # array indexing
          ["/bin/bash", "-c", "jq 'length' array.json | grep -q '^5$'"], # array length
          ["/bin/bash", "-c", "echo '{\"users\":[{\"name\":\"Bob\",\"age\":25},{\"name\":\"Carol\",\"age\":35}]}' > nested.json"],
          ["/bin/bash", "-c", "jq '.users[0].name' nested.json | grep -q '\"Bob\"'"], # nested access
          ["/bin/bash", "-c", "jq '.users | length' nested.json | grep -q '^2$'"], # nested array length
          ["/bin/bash", "-c", "jq '.users[].age' nested.json > ages.txt"],
          # verify map operation
          ["/bin/bash", "-c", "echo '25\n35' > expected_ages.txt"],
          ["/bin/diff", "-q", "ages.txt", "expected_ages.txt"],
          # verify object construction
          ["/bin/bash", "-c", "echo '{\"a\":1,\"b\":2}' | jq '{a,b}' > reformed.json"],
          ["/bin/bash", "-c", "jq '.a' reformed.json | grep -q '^1$'"],
        ],
      } | Test,
    filtering =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '[{\"name\":\"x\",\"val\":10},{\"name\":\"y\",\"val\":20},{\"name\":\"z\",\"val\":5}]' > items.json"],
          ["/bin/bash", "-c", "jq '[.[] | select(.val > 10)]' items.json > filtered.json"],
          ["/bin/bash", "-c", "jq 'length' filtered.json | grep -q '^1$'"],
        ],
      } | Test,
    map =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '[{\"name\":\"x\",\"val\":10},{\"name\":\"y\",\"val\":20},{\"name\":\"z\",\"val\":5}]' > items.json"],
          ["/bin/bash", "-c", "jq 'map(.val * 2)' items.json > doubled.json"],
          ["/bin/bash", "-c", "jq '.[0]' doubled.json | grep -q '^20$'"],
        ],
      } | Test,
  },
} | BuildSpec
