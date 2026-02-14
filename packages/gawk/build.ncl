let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let readline = import "../readline/build.ncl" in

let version = "5.3.2" in
{
  name = "gawk",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-%{version}.tar.xz",
      sha256 = "f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    mpfr,
    readline,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/gawk/*.so" } | OutputLib,
    libexec = { glob = "usr/libexec/awk/*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,

    awk_data = { glob = "usr/share/awk/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gawk",
    } | Attrs,

  replace_on_cycle =
    {
      name = "gawk (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/gawk/arm64-linux-gnu/gawk_5.3.2_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "13f289193878abaaf5007b7d2e49f890d6672b114cdf3d7a30718707d45d978c",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputBin,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_libexec = { glob = "usr/libexec/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/gawk --version",

    matching =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'one two three\nfour five six' > data.txt"],
          ["/bin/bash", "-c", "gawk '{print $2}' data.txt > col2.txt"],
          ["/bin/bash", "-c", "echo 'two\nfive' > expected.txt"],
          ["/bin/diff", "-q", "col2.txt", "expected.txt"], # verify second column extracted
          ["/bin/bash", "-c", "gawk '/five/ {print $1}' data.txt | grep -q '^four$'"], # verify pattern matching
        ],
      } | Test,
  },
} | BuildSpec
