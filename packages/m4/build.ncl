let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.20" in
{
  name = "m4",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/m4-%{version}.tar.xz",
      sha256 = "e236ea3a1ccf5f6c270b1c4bb60726f371fa49459a8eaaebc90b216b328daf2b",
      extract = true,
      strip_prefix = "m4-%{version}",
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

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "m4 (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/m4/0e48c2baab84e74ed9916a01eecf0dbc0377e247a05220ea63536bd3d189d466.tar.zst",
              sha256 = "104907b54fb3edd8c0c18fddffbb5bacda1dea11c224118670c3cbb52ace8cce",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/m4/arm64-linux-gnu/m4_1.4.21_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "251ab6f5ae2cedd4ba79a82d30069fea7ab68747a592f4c2c22ab07c5f52f32b",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        bins = { glob = "usr/bin/**/*" } | OutputBin,
        mans = { glob = "usr/share/man/**" } | OutputData,
        infos = { glob = "usr/share/info/*.info" } | OutputData,
        locales = { glob = "usr/share/locale/**" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "m4",
      },
    } | Attrs,
} | BuildSpec
