let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash = import "../bash/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let xz = import "../xz/build.ncl" in
{
  name = "file",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/file-5.46.tar.gz",
      sha256 = "c9cc77c7c560c543135edc555af609d5619dbef011997e988ce40a3d75d86088"
    } | Source,
    bash,
    tar,
    make,
    sed,
    gawk,
    grep,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    lz4,
    xz,
  ],

  cmd = "./build.sh",
  outputs = {
    file = { glob = "usr/bin/file" } | OutputBin,

    libmagic = { glob = "usr/lib/libmagic.so*" } | OutputLib,
    data = { glob = "usr/share/misc/magic*" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "file (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/file/595683b1e5b1f4d571fe224eb0d19ebd61d55bcc64c09c67d0b1c1cecbf3046e.tar.zst",
              sha256 = "380fddc64d1f1ea0fc2d1044d3b6a4a9b48c91f2b3f8fbe46c7d1faa2d315837",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/file/arm64-linux-gnu/file_5.46_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "388a5c9a1889ab1b51d9adffef0450f2b125e9ade0bea9a548d539797cc8032b",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputBin,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      }
    } | BuildSpec,
  attrs =
    {
      source_provenance = {
        category = 'GithubRepo,
        owner = "file",
        repo = "file",
      },
    } | Attrs,
} | BuildSpec
