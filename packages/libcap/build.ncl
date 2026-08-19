let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.78" in
{
  name = "libcap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Home page: https://sites.google.com/site/fullycapable/
      # Download: https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.78.tar.xz
      url = "gs://minimal-staging-archives/libcap-%{version}.tar.xz",
      sha256 = "0d621e562fd932ccf67b9660fb018e468a683d7b827541df27813228c996bb11",
      extract = true,
      strip_prefix = "libcap-%{version}",
    } | Source,
    bash-bootstrap,
    diffutils,
    grep,
    make,
    sed,
    linux_headers,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause OR GPL-2.0-only",
      repology_project = "libcap",
    } | Attrs,

  replace_on_cycle =
    {
      name = "libcap (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/4f3f36dc8012b53c6b98714ad3df679767d95b0a02880ea27900a09bcc709f5e/stage0-libcap-amd-x86_64.tar.zst",
              sha256 = "4f3f36dc8012b53c6b98714ad3df679767d95b0a02880ea27900a09bcc709f5e",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/396c25c199b89ea2942bae1bbf28d847c058dbaaa559c5cd9e5fedf11ea011df/stage0-libcap-arm-aarch64.tar.zst",
              sha256 = "396c25c199b89ea2942bae1bbf28d847c058dbaaa559c5cd9e5fedf11ea011df",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
