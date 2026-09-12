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

let version = "2.44" in
{
  name = "glibc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Downloadable from: https://ftp.gnu.org/gnu/glibc/
      url = "gs://minimal-staging-archives/glibc-%{version}.tar.xz",
      sha256 = "37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667"
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
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/d0850b659687f160368bf87a57d02cfbbe0f1a5fe6ab4b623ca8296b5659126f/glibc-bedrock-2.42-2.42.tar.zst",
              sha256 = "d0850b659687f160368bf87a57d02cfbbe0f1a5fe6ab4b623ca8296b5659126f",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/a1d40cb10e77670c3c1b00bf2ce28f45775146dfe0397d4c4c5468e955bb1cdc/stage0-glibc-2.42-aarch64.tar.zst",
              sha256 = "a1d40cb10e77670c3c1b00bf2ce28f45775146dfe0397d4c4c5468e955bb1cdc",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = all_outputs,
    } | BuildSpec,
} | BuildSpec
