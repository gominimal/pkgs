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
              # BEDROCK ROOT (amd64): built from source by stage0-libcap-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              url = "gs://minimalmertic-hermetic-mirror/sha256/4f3f36dc8012b53c6b98714ad3df679767d95b0a02880ea27900a09bcc709f5e/stage0-libcap-amd-x86_64.tar.zst",
              sha256 = "4f3f36dc8012b53c6b98714ad3df679767d95b0a02880ea27900a09bcc709f5e",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): stage0-libcap-arm on our hex0-rooted toolchain, replacing the
              # dockcross/crosstool-NG artifact from bootstrap-aarch64-bins. Remaining deltas are
              # usr/share/doc/** the recipes never declare -- dockcross extras, not losses.
              # DIVERGENCE, deliberate: the dockcross artifact ships libcap.a/libpsx.a; ours does
              # not, because packages/libcap/build.sh DELETES the static install rule. Ours matches
              # the recipe; dockcross deviated from it. Static-linkers of libcap would break -- none
              # in base; the world rebuild is the census for the rest.
              url = "gs://minimalmertic-hermetic-mirror/sha256/396c25c199b89ea2942bae1bbf28d847c058dbaaa559c5cd9e5fedf11ea011df/stage0-libcap-arm-aarch64.tar.zst",
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
