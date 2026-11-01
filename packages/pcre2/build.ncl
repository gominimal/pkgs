let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
let zlib = import "../zlib/build.ncl" in

let version = "10.49" in
{
  name = "pcre2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pcre2-%{version}.tar.bz2",
      sha256 = "53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384"
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
    zlib,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    pcre2-config = { glob = "usr/bin/pcre2-config", allow_missing_interpreter = true } | OutputBin,
    pcre2grep = { glob = "usr/bin/pcre2grep" } | OutputBin,
    #pcre2test = { glob = "usr/bin/pcre2test" } | OutputBin, - does anything need this?

    libs = { glob = "usr/lib/libpcre2*.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libpcre2*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "pcre2 (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/581e0837bec6d847d46f805c04ff0d895ada1105e0ec4754df880800b3e988e8/pcre2-x86_64.tar.zst",
              sha256 = "581e0837bec6d847d46f805c04ff0d895ada1105e0ec4754df880800b3e988e8",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/d58d0f95a98c62db2ddd9dbebee64d1d6dc67ca7cb3c56e72488a7484210480a/pcre2-aarch64.tar.zst",
              sha256 = "d58d0f95a98c62db2ddd9dbebee64d1d6dc67ca7cb3c56e72488a7484210480a",
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
      license_spdx = "BSD-3-Clause WITH PCRE2-exception",
      repology_project = "pcre2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "PCRE2Project",
        repo = "pcre2",
      },
    } | Attrs,
} | BuildSpec
