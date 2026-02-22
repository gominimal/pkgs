let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14" in
{
  name = "gzip",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gzip-%{version}.tar.xz",
      sha256 = "01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "gzip",
      source_provenance = {
        category = 'GnuProject,
        name = "gzip",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "gzip (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gzip/578900779b149d12ff6b3268c3b473bb5d297b4f37d5730f821eccf22c5a7520.tar.zst",
              sha256 = "98aaf741d11c4edea8f53ac6c10d774dcce1fa524e64deb22affb72bb832ca81",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gzip/arm64-linux-gnu/gzip_1.14_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "02a7bf5a8edb319487f7ec48599b39430ef522cdc68f50ebf403df072f98f741",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        binaries = { glob = "usr/bin/*" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/gzip --version",

    zip_unzip =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'compress me' > original.txt"],
          ["/bin/bash", "-c", "cp original.txt original_copy.txt"],
          ["/bin/gzip", "original.txt"],
          ["/bin/bash", "-c", "test -f original.txt.gz"], # verify .gz exists
          ["/bin/gunzip", "original.txt.gz"],
          ["/bin/diff", "-q", "original.txt", "original_copy.txt"], # verify roundtrip
        ],
      } | Test,
  },
} | BuildSpec
