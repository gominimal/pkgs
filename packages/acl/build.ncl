let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let attr = import "../attr/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let sed = import "../sed/build.ncl" in

let version = "2.4.0" in
{
  name = "acl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/acl-%{version}.tar.xz",
      sha256 = "e661131456d2708a01c614a0f400e11d7d1bfaeb6f3e74b75bb980b72f0161a3",
      extract = true,
      strip_prefix = "acl-%{version}",
    } | Source,
    bash-bootstrap,
    binutils,
    coreutils,
    gawk-bootstrap,
    gcc,
    grep,
    make,
    linux_headers,
    sed,
  ],
  runtime_deps = [
    attr,
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    setfacl = { glob = "usr/bin/setfacl" } | OutputBin,
    chacl = { glob = "usr/bin/chacl" } | OutputBin,
    getfacl = { glob = "usr/bin/getfacl" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libacl.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "(GPL-2.0-only AND LGPL-2.1-only)",
  },

  replace_on_cycle =
    {
      name = "acl (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT (amd64): built from source by stage0-acl-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              url = "gs://minimalmertic-hermetic-mirror/sha256/ae9961c6cee91081c415ac924e34b5104fcb3160795183390cd46f4db93056b3/stage0-acl-amd-x86_64.tar.zst",
              sha256 = "ae9961c6cee91081c415ac924e34b5104fcb3160795183390cd46f4db93056b3",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): stage0-acl-arm on our hex0-rooted toolchain, replacing the
              # dockcross/crosstool-NG artifact from bootstrap-aarch64-bins. Remaining deltas are
              # usr/share/doc/** the recipes never declare -- dockcross extras, not losses.
              url = "gs://minimalmertic-hermetic-mirror/sha256/4896093cd26660c5eb6bf69e4fbe37f3c7a66eec8f4cf5042cf477c9822588bb/stage0-acl-arm-aarch64.tar.zst",
              sha256 = "4896093cd26660c5eb6bf69e4fbe37f3c7a66eec8f4cf5042cf477c9822588bb",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
