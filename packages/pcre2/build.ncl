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

let version = "10.47" in
{
  name = "pcre2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pcre2-%{version}.tar.bz2",
      sha256 = "47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7"
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
              # BEDROCK ROOT (amd64): stage0-pcre2-amd, COLD-rebuilt. slot-compare -> SLOT_SUPERSET.
              # The warm rebuild replayed a cached capture and appeared to drop usr/bin/pcre2test;
              # outputs are not part of the spec hash, so widening globs alone changes nothing.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/e43debe0442b2de6e863303c8af966f2146af3bb0d8b998f0539c9e3d5ac046a/stage0-pcre2-amd-x86_64.tar.zst",
              sha256 = "e43debe0442b2de6e863303c8af966f2146af3bb0d8b998f0539c9e3d5ac046a",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/2b397d27964854fe25060e887bfbcb2153da540dfe4e2a6a529c424476073ff4/stage0-pcre2-arm-aarch64.tar.zst",
              sha256 = "2b397d27964854fe25060e887bfbcb2153da540dfe4e2a6a529c424476073ff4",
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
