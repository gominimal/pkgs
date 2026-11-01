let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.21" in
{
  name = "m4",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/m4-%{version}.tar.xz",
      sha256 = "f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66",
      extract = true,
      strip_prefix = "m4-%{version}",
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    m4 = { glob = "usr/bin/m4" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "m4 (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/91ac0f4b7e7d3fd3069eefe7430f8b28ea036eab39b86287857e10957a0e1441/m4-x86_64.tar.zst",
              sha256 = "91ac0f4b7e7d3fd3069eefe7430f8b28ea036eab39b86287857e10957a0e1441",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/027e0d1a6fc0ede238d6d4b6fd9ecb4d824f14b0997ec26970837f8ea7435d41/m4-aarch64.tar.zst",
              sha256 = "027e0d1a6fc0ede238d6d4b6fd9ecb4d824f14b0997ec26970837f8ea7435d41",
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
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "m4",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/m4 --version",
  },
} | BuildSpec
