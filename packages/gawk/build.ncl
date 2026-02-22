let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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
      source_provenance = {
        category = 'GnuProject,
        name = "gawk",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "gawk (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gawk/2c668aca10691d29a89f767fc19208a30e037c65ab01dcfc10c338de3dcfb478.tar.zst",
              sha256 = "7c1b61fc5b0351ca48cc2ddb894ff84597295cb72c8a478ae5238b5ccd66cac8",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gawk/arm64-linux-gnu/gawk_5.3.2_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "7e3ac90eeb33dd512fb20f7d50a3d7081d747e10dd46b5955563567ff12278d1",
              extract = true,
            } | Source,
        } target,
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
