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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/34a996dadc172f926a2f9180c0e8a145455edd0e7654aa925985755526726bf7/attr-x86_64.tar.zst",
              sha256 = "34a996dadc172f926a2f9180c0e8a145455edd0e7654aa925985755526726bf7",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/07cccbe63f0ef39794cc8b5284d102d100e9663df13bb74b44cacb5dbe08eeea/attr-aarch64.tar.zst",
              sha256 = "07cccbe63f0ef39794cc8b5284d102d100e9663df13bb74b44cacb5dbe08eeea",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
