let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let m4 = import "../m4/build.ncl" in
let version = "6.3.0" in
{
  name = "gmp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gmp-%{version}.tar.xz",
      sha256 = "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
    } | Source,
    # base
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    linux_headers,
    # other
    m4
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  replace_on_cycle =
    {
      name = "gmp (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/7c59c8784fca293381dd717f56012164d1a171376bcf08b9528483eb1ed40ca9/gmp-x86_64.tar.zst",
              sha256 = "7c59c8784fca293381dd717f56012164d1a171376bcf08b9528483eb1ed40ca9",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/3da7136908ee2d63673fe320a60ee245b9220e56ac959afcd93f8d60f5da2443/gmp-aarch64.tar.zst",
              sha256 = "3da7136908ee2d63673fe320a60ee245b9220e56ac959afcd93f8d60f5da2443",
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
      license_spdx = "LGPL-3.0-or-later OR GPL-2.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "gmp",
      },
    } | Attrs,
} | BuildSpec
