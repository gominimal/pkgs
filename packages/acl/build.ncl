let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/80049b117f4eaae0053cccbb2cd2b02eb1a6f3f4a1b12a44f61814f6b31a833f/acl-x86_64.tar.zst",
              sha256 = "80049b117f4eaae0053cccbb2cd2b02eb1a6f3f4a1b12a44f61814f6b31a833f",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/f6784426cb1335c97acd3a6d296de476edb00928a0605345a58718cd28203ca2/acl-aarch64.tar.zst",
              sha256 = "f6784426cb1335c97acd3a6d296de476edb00928a0605345a58718cd28203ca2",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/usr/bin/getfacl --version",
  },
} | BuildSpec
