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
let version = "5.48" in
{
  name = "file",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Home page: https://www.darwinsys.com/file/
      # https://astron.com/pub/file/file-5.48.tar.gz
      url = "gs://minimal-staging-archives/file-%{version}.tar.gz",
      sha256 = "ed14656883b23a364b4057c05595d93252da9bc473d30106519519d0da141283"
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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/c6f5e729b3b3e2041f14a6d0df986002d3a9898eacc5d3a2807bc79301d3ebdb/file-x86_64.tar.zst",
              sha256 = "c6f5e729b3b3e2041f14a6d0df986002d3a9898eacc5d3a2807bc79301d3ebdb",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/fde05a89a2fd94ee08a838c628ef859349fbb739d66d026de7de6a5cf5d8d16c/file-aarch64.tar.zst",
              sha256 = "fde05a89a2fd94ee08a838c628ef859349fbb739d66d026de7de6a5cf5d8d16c",
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
      license_spdx = "BSD-2-Clause-Darwin",
    } | Attrs,
} | BuildSpec
