let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
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
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in
let python = import "../python/build.ncl" in

let all_outputs = {
  # Technically a few binaries (xtrace, ldd) depend on bash, but we omit that dep given how low-level glibc is +
  # practical uses of those tools are in a shell environment anyway.
  bins = { glob = "usr/bin/**", allow_missing_interpreter = true } | OutputBin,
  sbins = { glob = "usr/sbin/**" } | OutputBin,
  etc = { glob = "etc/**/*" } | OutputData,

  libs = { glob = "usr/lib/*.{so*,a}", allow_data = true } | OutputLib, # libc.so is a linker script, not an ELF binary
  crts = { glob = "usr/lib/{crt,gcrt,grcrt,Mcrt,rcrt,Scrt}*.o" } | OutputLib,
  lib_audit = { glob = "usr/lib/audit/*.so*" } | OutputLib,
  lib_locale = { glob = "usr/lib/locale/**" } | OutputData,
  lib_gconv = { glob = "usr/lib/gconv/**", allow_data = true } | OutputLib,

  libexec_getconf = { glob = "usr/libexec/getconf/**" } | OutputLib,

  i18n = { glob = "usr/share/i18n/**" } | OutputData,
  locales = { glob = "usr/share/locale/**" } | OutputData,

  includes = { glob = "usr/include/**" } | OutputData,
}
in

let version = "2.43" in
{
  name = "glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Downloadable from: https://ftp.gnu.org/gnu/glibc/
      url = "gs://minimal-staging-archives/glibc-%{version}.tar.xz",
      sha256 = "d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831"
    } | Source,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
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
    glibc,
    linux_headers,
    # other
    bison,
    m4,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = all_outputs,
  attrs =
    {
      upstream_version = version,
      license_spdx = "(GPL-2.0-only AND LGPL-2.1-only)",
      repology_project = "glibc",
      source_provenance = {
        category = 'GnuProject,
        name = "glibc",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "glibc (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimalmertic-release-channel-stable/glibc-bedrock-2.42-2.42/glibc-bedrock-2.42-2.42.tar.zst",
              sha256 = "d0850b659687f160368bf87a57d02cfbbe0f1a5fe6ab4b623ca8296b5659126f",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): our own hex0-rooted glibc-2.42 (R11), from the same sealed
              # ladder as the gcc and binutils roots. Already in an allowlisted bucket.
              # MEASURED against the tarball's entry list, not assumed: 472 headers at the STANDARD
              # usr/include path, 32 usr/lib/*.so*, all 8 crt objects, etc/ present. The versioned
              # usr/lib/glibc-bedrock-2.42/ tree (1701 entries) is an ADDITIONAL copy for -nostdinc
              # consumers, not a replacement -- the earlier "ships no headers" claim was an artifact
              # of a probe that PREFERRED the versioned path and never looked anywhere else.
              # KNOWN GAP: usr/lib/locale/** is empty (the foreign 2.40 root ships 1 file there),
              # so anything locale-dependent is the first place to expect trouble.
              url = "gs://minimal-staging-archives/bedrock/aarch64/20260804/stage0-glibc-2.42-aarch64.tar.zst",
              sha256 = "df3ae0df80cfe293f3b3f30ebb2a4638ae3add832f99e287c6ea7a2aa7430cf5",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = all_outputs,
    } | BuildSpec,
} | BuildSpec
