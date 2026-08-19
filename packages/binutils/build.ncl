let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.47" in
{
  name = "binutils",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
      sha256 = "154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
    # base
    bash-bootstrap,
    coreutils,
    diffutils,
    gawk-bootstrap,
    grep,
    make,
    perl,
    sed,
    # toolchain
    binutils,
    gcc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    zlib,
    subsetOf gcc ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    addr2line = { glob = "usr/bin/addr2line" } | OutputBin,
    ar = { glob = "usr/bin/ar" } | OutputBin,
    as = { glob = "usr/bin/as" } | OutputBin,
    cppfilt = { glob = "usr/bin/c++filt" } | OutputBin,
    elfedit = { glob = "usr/bin/elfedit" } | OutputBin,
    gp = { glob = "usr/bin/{gp,gprof}*", allow_missing_interpreter = true } | OutputBin,
    ld = { glob = "usr/bin/ld*" } | OutputBin,
    nm = { glob = "usr/bin/nm" } | OutputBin,
    objcopy = { glob = "usr/bin/objcopy" } | OutputBin,
    objdump = { glob = "usr/bin/objdump" } | OutputBin,
    ranlib = { glob = "usr/bin/ranlib" } | OutputBin,
    readelf = { glob = "usr/bin/readelf" } | OutputBin,
    size = { glob = "usr/bin/size" } | OutputBin,
    strings = { glob = "usr/bin/strings" } | OutputBin,
    strip = { glob = "usr/bin/strip" } | OutputBin,

    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    ldscripts = { glob = "usr/lib/ldscripts/*" } | OutputData,

    gprofng_libs = { glob = "usr/lib/gprofng/*.so*" } | OutputLib,
    gprofng_ltconfigs = { glob = "usr/lib/gprofng/*.la" } | OutputData,

    bfdplugins = { glob = "usr/lib/bfd-plugins/**" } | OutputLib,

    etcs = { glob = "etc/*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GPL-2.0-only AND GPL-3.0-only AND LGPL-2.0-only)",
      repology_project = "binutils",
      source_provenance = {
        category = 'GnuProject,
        name = "binutils",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "binutils (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/e796366aca5bb03f1e082598b4c3824ad3c95e0001b961a6d339da8c19f836bb/binutils-2.46-glibc-2.46.0.tar.zst",
              sha256 = "e796366aca5bb03f1e082598b4c3824ad3c95e0001b961a6d339da8c19f836bb",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/2c94c3d9ae665bcaacc52e4a6ea53d29e4d4904877b4d698f573d3e1d6356626/stage0-binutils-2.41-aarch64.tar.zst",
              sha256 = "2c94c3d9ae665bcaacc52e4a6ea53d29e4d4904877b4d698f573d3e1d6356626",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        zlib,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
