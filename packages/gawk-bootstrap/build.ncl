let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in

let version = "5.4.1" in
{
  name = "gawk-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-%{version}.tar.xz",
      sha256 = "07f6f7342b7febe4313fc2c2542ad93d64fe20ad8717200109f105a826f5fd37"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    mpfr,
  ],

  cmd = "./build.sh",
  outputs = {
    gawk_versioned = { glob = "usr/bin/gawk-*" } | OutputBin,
    gawk = { glob = "usr/bin/gawk" } | OutputBin,
    awk = { glob = "usr/bin/awk" } | OutputBin,
    libs = { glob = "usr/lib/gawk/*.so" } | OutputLib,
    libexec = { glob = "usr/libexec/awk/*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,

    awk_data = { glob = "usr/share/awk/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GnuProject,
      name = "gawk",
    },
    license_spdx = "GPL-3.0-only",
  },

  replace_on_cycle =
    {
      name = "gawk-bootstrap (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/add1c9fe82395d4449943dfa0fa771e0934d99663eed8168e2ed92b383161c2f/gawk-bootstrap-x86_64.tar.zst",
              sha256 = "add1c9fe82395d4449943dfa0fa771e0934d99663eed8168e2ed92b383161c2f",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/525651d53e43df1c89ebaf0cc2785bcadbcf514d28499bbc4ad7107ece1602b5/gawk-bootstrap-aarch64.tar.zst",
              sha256 = "525651d53e43df1c89ebaf0cc2785bcadbcf514d28499bbc4ad7107ece1602b5",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputBin,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_libexec = { glob = "usr/libexec/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
