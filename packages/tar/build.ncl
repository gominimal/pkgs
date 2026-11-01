let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let acl = import "../acl/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "1.35" in
{
  name = "tar",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tar-%{version}.tar.xz",
      sha256 = "4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16"
    } | Source,
    base-bootstrap,
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
      license_spdx = "GPL-3.0-only",
      repology_project = "tar",
      source_provenance = {
        category = 'GnuProject,
        name = "tar",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "tar (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/193c6e1829ff3020a595e25e60a75ce1fbe1f960d1cc0b3286e031611bf35a22/tar-x86_64.tar.zst",
              sha256 = "193c6e1829ff3020a595e25e60a75ce1fbe1f960d1cc0b3286e031611bf35a22",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/ed025245c3762391362e38344111ca99b727a7f5dca8e25db3e95ae56a842f7a/tar-aarch64.tar.zst",
              sha256 = "ed025245c3762391362e38344111ca99b727a7f5dca8e25db3e95ae56a842f7a",
              extract = true,
            } | Source,
        } target,
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
        test_deps = [base-bootstrap],
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
