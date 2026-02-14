let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let acl = import "../acl/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "1.35" in
{
  name = "tar",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tar-%{version}.tar.xz",
      sha256 = "4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    acl,
    glibc,
    gzip,
    xz,
  ],

  cmd = "./build.sh",
  outputs = {
    tar = { glob = "usr/bin/tar" } | OutputBin,
    rmt = { glob = "usr/libexec/rmt" } | OutputLib,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "tar",
    } | Attrs,

  replace_on_cycle =
    {
      name = "tar (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/tar/arm64-linux-gnu/tar_1.35_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "6d94ca81465fe813cbbd7f350abb01b0795c5e868195cf2723ac1c684ba247dc",
          extract = true,
        } | Source,
      ],
      runtime_deps = [
        acl,
        glibc,
        gzip,
        xz,
      ],
      outputs = {
        tar = { glob = "usr/bin/tar" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/tar --version",

    compress_extract =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'content1' > file1.txt"],
          ["/bin/bash", "-c", "echo 'content2' > file2.txt"],
          ["/bin/tar", "-czf", "archive.tar.gz", "file1.txt", "file2.txt"],
          ["/bin/bash", "-c", "mkdir extract_dir && tar -xzf archive.tar.gz -C extract_dir"],
          ["/bin/diff", "-q", "file1.txt", "extract_dir/file1.txt"],
          ["/bin/diff", "-q", "file2.txt", "extract_dir/file2.txt"],
        ],
      } | Test,
  },
} | BuildSpec
