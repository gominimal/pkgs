let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in

# TODO: When packaging i see errors like: /usr/bin/bison: m4 subprocess failed: No such file or directory
# Maybe m4 needs to be a runtime_dep here?
let base = import "../base/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.8.2" in
{
  name = "bison",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/bison-%{version}.tar.xz",
      sha256 = "9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2"
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    flex,
    m4,
    toolchain,
  ],
  runtime_deps = [
    bash, # yacc is a shell script
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bison = { glob = "usr/bin/bison" } | OutputBin,
    yacc = { glob = "usr/bin/yacc" } | OutputBin,

    liby = { glob = "usr/lib/liby.a" } | OutputLib,

    bison_share = { glob = "usr/share/bison/**/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "bison (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/e131fa2e001d518be7afea3b3d4690a52a63a34a7b1264d2dd27b1b9a90ceb96/stage0-bison-amd-x86_64.tar.zst",
              sha256 = "e131fa2e001d518be7afea3b3d4690a52a63a34a7b1264d2dd27b1b9a90ceb96",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/fb6b49db2a329390fd56890248164670f300f0ae8c231d260fbc40268fc40bf3/stage0-bison-arm-aarch64.tar.zst",
              sha256 = "fb6b49db2a329390fd56890248164670f300f0ae8c231d260fbc40268fc40bf3",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "bison",
      },
    } | Attrs,
} | BuildSpec
