let { BuildSpec, Local, OutputBin, OutputLib, Prebuilt, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
{
  name = "m4",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/m4-1.4.20.tar.xz",
      sha256 = "e236ea3a1ccf5f6c270b1c4bb60726f371fa49459a8eaaebc90b216b328daf2b"
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
    usr_bin = { glob = "usr/bin/**/*" } | OutputBin,
    usr_share = { glob = "usr/share/**/*" } | OutputLib,
  },

  replace_on_cycle =
    {
      name = "m4 (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/m4/0e48c2baab84e74ed9916a01eecf0dbc0377e247a05220ea63536bd3d189d466.tar.zst",
          sha256 = "104907b54fb3edd8c0c18fddffbb5bacda1dea11c224118670c3cbb52ace8cce",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
