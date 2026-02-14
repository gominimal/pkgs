let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
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
    } | Attrs,

  replace_on_cycle =
    {
      name = "gzip (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/gzip/arm64-linux-gnu/gzip_1.14_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "99f398822f33d0e759842b1a4205327f7cc588d3ba34508a56bc2c6b729503db",
          extract = true,
        } | Source,
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
