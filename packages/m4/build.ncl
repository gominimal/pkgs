let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
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
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/fcd2408d7c45d11f0ab9b9c63261814e2882f9ba9cafc0ebcc8006810575cf4d/stage0-m4-amd-x86_64.tar.zst",
              sha256 = "fcd2408d7c45d11f0ab9b9c63261814e2882f9ba9cafc0ebcc8006810575cf4d",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/7281618383241388a86632d589d1a72acc54a78c2751d618e9eeb3be2af62e72/stage0-m4-arm-aarch64.tar.zst",
              sha256 = "7281618383241388a86632d589d1a72acc54a78c2751d618e9eeb3be2af62e72",
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
} | BuildSpec
