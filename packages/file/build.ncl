let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let xz = import "../xz/build.ncl" in
let version = "5.47" in
{
  name = "file",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Home page: https://www.darwinsys.com/file/
      # https://astron.com/pub/file/file-5.47.tar.gz
      url = "gs://minimal-staging-archives/file-%{version}.tar.gz",
      sha256 = "45672fec165cb4cc1358a2d76b5d57d22876dcb97ab169427ac385cbe1d5597a"
    } | Source,
    bash-bootstrap,
    tar,
    make,
    sed,
    gawk-bootstrap,
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
  build_args = {
    include version,
  },

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
      build_deps = [
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
              sha256 = "405f9433716791c108025de925ca77d9b4c9be6fc1cc0e1ab62c44a2a061225e",
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
      upstream_version = version,
    } | Attrs,
} | BuildSpec
