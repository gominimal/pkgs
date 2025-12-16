let { BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let acl = import "../acl/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let xz = import "../xz/build.ncl" in
{
  name = "tar",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tar-1.35.tar.xz",
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
    info = { glob = "usr/share/info/tar.info*" } | OutputLib,
    locale_files = { glob = "usr/share/locale/**/*" } | OutputLib,
  },

  replace_on_cycle =
    {
      name = "tar (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/tar/b2215579b4fe963bdd7d5c9ec96393f50b52f25942e021b25447d0eb72e634a4.tar.zst",
          sha256 = "c0d8ecf7bf311d04596aebb46aadc976afecb64f79b1e56e914becd8820b7cfd",
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
} | BuildSpec
