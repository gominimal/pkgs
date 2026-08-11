let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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

let version = "2.6.0" in
{
  name = "attr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/attr-%{version}.tar.gz",
      sha256 = "d42fa374513180bb48cb11a46696f488240e5124ff1e6ad88b0abff706985612",
      extract = true,
      strip_prefix = "attr-%{version}",
    } | Source,
    bash-bootstrap,
    binutils,
    coreutils,
    gawk-bootstrap,
    gcc,
    glibc,
    grep,
    make,
    linux_headers,
    sed,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    attr = { glob = "usr/bin/attr" } | OutputBin,
    setfattr = { glob = "usr/bin/setfattr" } | OutputBin,
    getfattr = { glob = "usr/bin/getfattr" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libattr.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    etcs = { glob = "etc/*" } | OutputData,
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
      name = "attr (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT (amd64): built from source by stage0-attr-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              url = "gs://minimalmertic-hermetic-mirror/sha256/237b893326065698a43055db46dacf8102e79fd2480e8d8de1895e9a45a51c60/stage0-attr-amd-x86_64.tar.zst",
              sha256 = "237b893326065698a43055db46dacf8102e79fd2480e8d8de1895e9a45a51c60",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/attr/arm64-linux-gnu/attr_2.5.2_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "ced805c915840840cedff8dfedfd222a4a06d1030c69899d49c63c34051e9d34",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
